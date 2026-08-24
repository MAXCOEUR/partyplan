namespace PartyPlan.UnitTests;

using System.Net;
using Microsoft.Extensions.Logging.Abstractions;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.UnitTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Obtention du jeton OAuth2 exigé par FCM HTTP v1.
/// <para>
/// Le jeton est caché : le redemander à chaque notification ajouterait un aller-retour
/// réseau par envoi, et la limite de débit de Google finirait par le refuser.
/// </para>
/// </summary>
public sealed class GoogleAccessTokensTests
{
    private static readonly ServiceAccountKey Cle = LireCleDeTest();

    [Fact]
    public async Task Le_jeton_est_demande_a_l_adresse_d_echange_de_google()
    {
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.OK,
            """{"access_token":"jeton-1","expires_in":3600,"token_type":"Bearer"}"""));

        var jetons = Creer(stub, out _);

        var jeton = await jetons.ObtenirAsync(Cle, CancellationToken.None);

        jeton.ShouldBe("jeton-1");
        stub.Appels.Count.ShouldBe(1);
        stub.Appels[0].Uri.ShouldBe("https://oauth2.googleapis.com/token");
        // Le format d'échange est imposé par la RFC 7523.
        stub.Appels[0].Corps.ShouldContain("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer");
        stub.Appels[0].Corps.ShouldContain("assertion=");
    }

    [Fact]
    public async Task Un_second_appel_rapproche_reutilise_le_jeton_cache()
    {
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.OK,
            """{"access_token":"jeton-1","expires_in":3600}"""));

        var jetons = Creer(stub, out var horloge);

        await jetons.ObtenirAsync(Cle, CancellationToken.None);
        horloge.Avancer(TimeSpan.FromMinutes(30));
        var second = await jetons.ObtenirAsync(Cle, CancellationToken.None);

        second.ShouldBe("jeton-1");
        stub.Appels.Count.ShouldBe(1, "le jeton caché devait suffire");
    }

    [Fact]
    public async Task Un_jeton_proche_de_l_expiration_est_renouvele()
    {
        var reponses = 0;
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.OK,
            $$"""{"access_token":"jeton-{{++reponses}}","expires_in":3600}"""));

        var jetons = Creer(stub, out var horloge);

        await jetons.ObtenirAsync(Cle, CancellationToken.None);
        // La marge de sécurité est d'une minute : à 59 min 10 s, le jeton doit tourner.
        horloge.Avancer(TimeSpan.FromMinutes(59) + TimeSpan.FromSeconds(10));
        var second = await jetons.ObtenirAsync(Cle, CancellationToken.None);

        second.ShouldBe("jeton-2");
        stub.Appels.Count.ShouldBe(2);
    }

    [Fact]
    public async Task Un_refus_de_google_renvoie_null_sans_lever()
    {
        var stub = new HttpStub(_ => HttpStub.Json(
            HttpStatusCode.BadRequest,
            """{"error":"invalid_grant"}"""));

        var jetons = Creer(stub, out _);

        // Renvoyer null plutôt que lever : l'appelant journalise et abandonne l'envoi,
        // il ne fait pas échouer l'action métier qui l'a déclenché.
        (await jetons.ObtenirAsync(Cle, CancellationToken.None)).ShouldBeNull();
    }

    [Fact]
    public async Task Un_refus_n_est_pas_mis_en_cache()
    {
        var reponses = 0;
        var stub = new HttpStub(_ => ++reponses == 1
            ? HttpStub.Json(HttpStatusCode.ServiceUnavailable, "{}")
            : HttpStub.Json(HttpStatusCode.OK, """{"access_token":"jeton-2","expires_in":3600}"""));

        var jetons = Creer(stub, out _);

        (await jetons.ObtenirAsync(Cle, CancellationToken.None)).ShouldBeNull();
        // Cacher un échec priverait l'instance de notifications pendant une heure.
        (await jetons.ObtenirAsync(Cle, CancellationToken.None)).ShouldBe("jeton-2");
    }

    // ------------------------------------------------------------------ aides ----

    private static GoogleAccessTokens Creer(HttpStub stub, out HorlogeDeTest horloge)
    {
        horloge = new HorlogeDeTest();
        return new GoogleAccessTokens(
            new HttpClient(stub),
            horloge,
            NullLogger<GoogleAccessTokens>.Instance);
    }

    private static ServiceAccountKey LireCleDeTest()
    {
        var chemin = ServiceAccountKeyTests.EcrireCleValide();
        try
        {
            return ServiceAccountKey.Lire(chemin, out _)!;
        }
        finally
        {
            File.Delete(chemin);
        }
    }
}
