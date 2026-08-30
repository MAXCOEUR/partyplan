namespace PartyPlan.UnitTests;

using System.Net;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.UnitTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Envoi d'une notification par FCM HTTP v1.
/// <para>
/// Aucun de ces tests ne sort sur le réseau : la frontière est le <c>HttpClient</c>
/// (NF-DEV-10). Ce qui est vérifié, c'est le corps envoyé et le traitement des réponses,
/// pas la capacité de Google à livrer.
/// </para>
/// </summary>
public sealed class FirebasePushSenderTests
{
    private const string Jeton = "fZ1p:APA91bH_exemple-de-jeton-fcm_qui-est-long";

    [Fact]
    public async Task Le_corps_suit_le_format_http_v1()
    {
        var stub = Stub(HttpStatusCode.OK, """{"name":"projects/p/messages/1"}""");
        var registre = new RegistreDeTest();
        var emetteur = Creer(stub, registre);

        await emetteur.SendAsync(
            new PushMessage(Jeton, "Soirée modifiée", "Le lieu a changé", "/events/42"),
            CancellationToken.None);

        stub.Appels.Count.ShouldBe(2, "un échange de jeton, puis l'envoi");
        stub.Appels[1].Uri
            .ShouldBe("https://fcm.googleapis.com/v1/projects/partyplan-test/messages:send");

        var corps = JsonDocument.Parse(stub.Appels[1].Corps).RootElement.GetProperty("message");
        corps.GetProperty("token").GetString().ShouldBe(Jeton);
        corps.GetProperty("notification").GetProperty("title").GetString()
            .ShouldBe("Soirée modifiée");
        corps.GetProperty("notification").GetProperty("body").GetString()
            .ShouldBe("Le lieu a changé");
        // Le lien voyage en données et non en notification : c'est le client qui décide
        // quoi ouvrir, le système n'a pas à connaître nos routes.
        corps.GetProperty("data").GetProperty("deepLink").GetString().ShouldBe("/events/42");
    }

    [Fact]
    public async Task Le_message_porte_une_cle_de_groupe_par_evenement()
    {
        // Même couture que les tests existants de ce fichier : la frontière est le
        // HttpClient (NF-DEV-10), et ce qui se vérifie est le corps envoyé.
        var stub = Stub(HttpStatusCode.OK, """{"name":"projects/p/messages/1"}""");
        var emetteur = Creer(stub, new RegistreDeTest());

        await emetteur.SendAsync(
            new PushMessage(Jeton, "Lucas", "On arrive.", "/events/42", GroupKey: "event:42"),
            CancellationToken.None);

        var corps = JsonDocument.Parse(stub.Appels[1].Corps).RootElement.GetProperty("message");
        corps.GetProperty("data").GetProperty("groupe").GetString().ShouldBe("event:42");
    }

    [Fact]
    public async Task Un_message_sans_lien_ne_porte_pas_de_champ_vide()
    {
        var stub = Stub(HttpStatusCode.OK, """{"name":"n"}""");
        var emetteur = Creer(stub, new RegistreDeTest());

        await emetteur.SendAsync(
            new PushMessage(Jeton, "Titre", "Corps"),
            CancellationToken.None);

        var corps = JsonDocument.Parse(stub.Appels[1].Corps).RootElement.GetProperty("message");
        corps.TryGetProperty("data", out _).ShouldBeFalse();
    }

    [Fact]
    public async Task Un_jeton_perime_est_mis_au_rebut()
    {
        var stub = new HttpStub(requete => requete.RequestUri!.ToString().Contains("fcm")
            ? HttpStub.Json(
                HttpStatusCode.NotFound,
                """
                {"error":{"code":404,"status":"NOT_FOUND","details":[
                  {"@type":"type.googleapis.com/google.firebase.fcm.v1.FcmError",
                   "errorCode":"UNREGISTERED"}]}}
                """)
            : HttpStub.Json(HttpStatusCode.OK, """{"access_token":"j","expires_in":3600}"""));

        var registre = new RegistreDeTest();
        var emetteur = Creer(stub, registre);

        await emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None);

        // Un téléphone réinstallé ne doit pas faire échouer les envois indéfiniment.
        registre.Rebuts.ShouldContain(Jeton);
    }

    [Fact]
    public async Task Une_panne_passagere_ne_met_rien_au_rebut()
    {
        var stub = new HttpStub(requete => requete.RequestUri!.ToString().Contains("fcm")
            ? HttpStub.Json(HttpStatusCode.ServiceUnavailable, """{"error":{"status":"UNAVAILABLE"}}""")
            : HttpStub.Json(HttpStatusCode.OK, """{"access_token":"j","expires_in":3600}"""));

        var registre = new RegistreDeTest();
        var emetteur = Creer(stub, registre);

        await emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None);

        // FCM indisponible n'est pas un jeton invalide : désactiver l'appareil ici
        // couperait les notifications de tout le monde à la première panne de Google.
        registre.Rebuts.ShouldBeEmpty();
    }

    [Fact]
    public async Task Un_echec_reseau_ne_leve_pas()
    {
        var stub = new HttpStub(_ => throw new HttpRequestException("réseau coupé"));
        var emetteur = Creer(stub, new RegistreDeTest());

        // Le contrat l'exige : perdre l'avis vaut mieux que perdre l'action qui l'a
        // déclenché.
        await Should.NotThrowAsync(() =>
            emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None));
    }

    [Fact]
    public async Task Sans_jeton_d_acces_aucun_envoi_n_est_tente()
    {
        var stub = new HttpStub(requete => requete.RequestUri!.ToString().Contains("oauth2")
            ? HttpStub.Json(HttpStatusCode.BadRequest, """{"error":"invalid_grant"}""")
            : HttpStub.Json(HttpStatusCode.OK, "{}"));

        var emetteur = Creer(stub, new RegistreDeTest());

        await emetteur.SendAsync(new PushMessage(Jeton, "T", "C"), CancellationToken.None);

        stub.Appels.ShouldHaveSingleItem();
        stub.Appels[0].Uri.ShouldContain("oauth2");
    }

    // ------------------------------------------------------------------ aides ----

    /// <summary>
    /// Doublure servant d'abord le jeton d'accès, puis la réponse FCM demandée. Sans
    /// l'échange OAuth2 réussi, aucun envoi n'est tenté et le test ne mesurerait rien.
    /// </summary>
    private static HttpStub Stub(HttpStatusCode statut, string corps) =>
        new(requete => requete.RequestUri!.ToString().Contains("oauth2", StringComparison.Ordinal)
            ? HttpStub.Json(HttpStatusCode.OK, """{"access_token":"j","expires_in":3600}""")
            : HttpStub.Json(statut, corps));

    private static FirebasePushSender Creer(HttpStub stub, IPushDeviceRegistry registre)
    {
        var chemin = ServiceAccountKeyTests.EcrireCleValide();
        ServiceAccountKey cle;
        try
        {
            cle = ServiceAccountKey.Lire(chemin, out _)!;
        }
        finally
        {
            File.Delete(chemin);
        }

        var client = new HttpClient(stub);

        return new FirebasePushSender(
            cle,
            new GoogleAccessTokens(client, new HorlogeDeTest(), NullLogger<GoogleAccessTokens>.Instance),
            client,
            registre,
            NullLogger<FirebasePushSender>.Instance);
    }

    private sealed class RegistreDeTest : IPushDeviceRegistry
    {
        internal List<string> Rebuts { get; } = [];

        public Task DisableAsync(string token, string raison, CancellationToken cancellationToken)
        {
            Rebuts.Add(token);
            return Task.CompletedTask;
        }
    }
}
