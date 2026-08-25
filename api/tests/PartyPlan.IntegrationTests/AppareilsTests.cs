namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Enregistrement des appareils recevant les notifications.
/// <para>
/// Un jeton FCM est renvoyé par le système à chaque lancement de l'application :
/// l'idempotence n'est pas un raffinement, c'est ce qui empêche <c>push_devices</c> de
/// grossir à chaque ouverture et chaque notification de partir en plusieurs exemplaires.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class AppareilsTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    /// <summary>Jeton réaliste : un jeton FCM porte « : », « _ » et « - ».</summary>
    private const string Jeton =
        "fZ1pQw3kR0m:APA91bH_exemple-de-jeton-fcm_assez-long-pour-etre-realiste";

    [Fact]
    public async Task Un_appelant_anonyme_ne_peut_pas_enregistrer_d_appareil()
    {
        using var client = fixture.CreateClient();

        var reponse = await client.PostAsJsonAsync(
            new Uri("/v1/me/devices", UriKind.Relative),
            new { token = Jeton, platform = "android" });

        reponse.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Un_appareil_s_enregistre_puis_se_retire()
    {
        using var client = await ConnecteAsync();

        (await client.PostAsJsonAsync(
                new Uri("/v1/me/devices", UriKind.Relative),
                new { token = Jeton, platform = "android" }))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CompterAsync(Jeton)).ShouldBe(1);

        (await client.DeleteAsync(new Uri($"/v1/me/devices/{Uri.EscapeDataString(Jeton)}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CompterAsync(Jeton)).ShouldBe(0);
    }

    [Fact]
    public async Task Un_reenregistrement_ne_cree_pas_un_second_appareil()
    {
        using var client = await ConnecteAsync();
        var jeton = $"{Jeton}-rejeu";

        for (var i = 0; i < 3; i++)
        {
            (await client.PostAsJsonAsync(
                    new Uri("/v1/me/devices", UriKind.Relative),
                    new { token = jeton, platform = "android" }))
                .StatusCode.ShouldBe(HttpStatusCode.NoContent);
        }

        (await CompterAsync(jeton)).ShouldBe(1);
    }

    [Fact]
    public async Task Un_jeton_deja_rattache_a_un_autre_compte_est_reaffecte()
    {
        var jeton = $"{Jeton}-pret";

        using var premier = await ConnecteAsync();
        await premier.PostAsJsonAsync(
            new Uri("/v1/me/devices", UriKind.Relative),
            new { token = jeton, platform = "android" });

        using var second = await ConnecteAsync();
        (await second.PostAsJsonAsync(
                new Uri("/v1/me/devices", UriKind.Relative),
                new { token = jeton, platform = "android" }))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // Une seule ligne, rattachée au dernier compte : le téléphone prêté ne doit plus
        // recevoir les notifications de son précédent titulaire.
        (await CompterAsync(jeton)).ShouldBe(1);
    }

    [Fact]
    public async Task Une_plateforme_inconnue_est_refusee()
    {
        using var client = await ConnecteAsync();

        var reponse = await client.PostAsJsonAsync(
            new Uri("/v1/me/devices", UriKind.Relative),
            new { token = $"{Jeton}-blackberry", platform = "blackberry" });

        // Un fourre-tout non validé finit par contenir trois orthographes de la même
        // plateforme, et aucune requête ne sait plus les retrouver.
        reponse.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Un_jeton_vide_est_refuse()
    {
        using var client = await ConnecteAsync();

        (await client.PostAsJsonAsync(
                new Uri("/v1/me/devices", UriKind.Relative),
                new { token = "  ", platform = "android" }))
            .StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Retirer_un_jeton_inconnu_reussit_sans_rien_faire()
    {
        using var client = await ConnecteAsync();

        // Idempotent : le client retire son jeton à la déconnexion, sans savoir si le
        // serveur le connaît. Un 404 le ferait échouer pour rien.
        (await client.DeleteAsync(new Uri("/v1/me/devices/jeton-jamais-vu", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);
    }

    // ------------------------------------------------------------------ aides ----

    private async Task<HttpClient> ConnecteAsync()
    {
        using var anonyme = fixture.CreateClient();
        var adresse = $"appareil-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = adresse, password = MotDePasse, displayName = "Porteur" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            corps.GetProperty("accessToken").GetString());

        return client;
    }

    private async Task<int> CompterAsync(string jeton)
    {
        var compte = 0;

        await fixture.WithDatabaseAsync(async db =>
            compte = await db.PushDevices.CountAsync(a => a.Token == jeton));

        return compte;
    }
}
