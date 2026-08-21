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
/// Changement de mot de passe imposé avant toute autre action (RG-ADM-10).
/// <para>
/// Le parcours entier est vérifié, pas seulement le refus : un compte tenu de changer
/// son mot de passe doit pouvoir le faire, puis se servir de l'application. Sans le
/// renouvellement du jeton, la revendication portée par l'ancien jeton maintiendrait le
/// refus pendant toute sa durée de vie, et l'application boucle.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class ChangementMotDePasseImposeTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasseInitial = "Trombone-Nuage-42x";

    private const string MotDePasseChoisi = "Cerf-Volant-Mauve-77";

    [Fact]
    public async Task Un_compte_tenu_de_changer_son_mot_de_passe_est_refuse_ailleurs()
    {
        var (client, _) = await CompteAChangerAsync();

        var refus = await client.GetAsync(new Uri("/v1/events", UriKind.Relative));

        refus.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await Code(refus)).ShouldBe("auth.must_change_password");
    }

    [Fact]
    public async Task Le_renouvellement_du_jeton_reste_possible()
    {
        // Sans cette autorisation, aucun client ne peut obtenir un jeton reflétant le
        // changement : le refus survivrait à la correction qu'il exige.
        var (client, rafraichissement) = await CompteAChangerAsync();

        var reponse = await client.PostAsJsonAsync(
            new Uri("/v1/auth/refresh", UriKind.Relative),
            new { refreshToken = rafraichissement });

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Apres_changement_et_renouvellement_le_compte_agit_normalement()
    {
        var (client, rafraichissement) = await CompteAChangerAsync();

        var changement = await client.PostAsJsonAsync(
            new Uri("/v1/auth/password/change", UriKind.Relative),
            new { currentPassword = MotDePasseInitial, newPassword = MotDePasseChoisi });

        changement.StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var renouvellement = await client.PostAsJsonAsync(
            new Uri("/v1/auth/refresh", UriKind.Relative),
            new { refreshToken = rafraichissement });

        renouvellement.StatusCode.ShouldBe(HttpStatusCode.OK);

        var jetons = await renouvellement.Content.ReadFromJsonAsync<JsonDocument>();
        var acces = jetons!.RootElement.GetProperty("accessToken").GetString();

        using var apres = fixture.CreateClient();
        apres.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        // Le jeton renouvelé ne porte plus la revendication : la liste devient lisible.
        (await apres.GetAsync(new Uri("/v1/events", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    /// <summary>
    /// Inscrit un compte, puis pose l'obligation de changement directement en base.
    /// Passer par l'amorçage de l'administrateur exigerait un mot de passe propre à la
    /// configuration de test : le raccourci porte sur la mise en place, pas sur ce qui
    /// est vérifié.
    /// </summary>
    private async Task<(HttpClient client, string rafraichissement)> CompteAChangerAsync()
    {
        var adresse = $"impose-{Guid.NewGuid():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();
        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = adresse, password = MotDePasseInitial, displayName = "Imposé" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Email == adresse);
            compte.MustChangePassword = true;
            await db.SaveChangesAsync();
        });

        // Le jeton d'inscription est antérieur à la marque : un renouvellement le fait
        // porter la revendication, comme après une connexion ordinaire.
        var corps = await inscription.Content.ReadFromJsonAsync<JsonDocument>();
        var rafraichissement = corps!.RootElement.GetProperty("refreshToken").GetString()!;

        var renouvellement = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/refresh", UriKind.Relative),
            new { refreshToken = rafraichissement });

        renouvellement.StatusCode.ShouldBe(HttpStatusCode.OK);

        var jetons = await renouvellement.Content.ReadFromJsonAsync<JsonDocument>();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            jetons!.RootElement.GetProperty("accessToken").GetString());

        return (client, jetons.RootElement.GetProperty("refreshToken").GetString()!);
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.TryGetProperty("code", out var code)
            ? code.GetString()
            : null;
    }
}
