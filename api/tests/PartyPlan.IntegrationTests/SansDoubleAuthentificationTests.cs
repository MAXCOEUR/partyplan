namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Absence de double authentification (ADR 0007).
/// <para>
/// La fonctionnalité est retirée : ni endpoint, ni colonne, ni défi à la connexion, ni
/// obligation pour un rôle plateforme. Ces tests fixent le retrait dans ses quatre
/// dimensions, parce qu'un retrait partiel est pire que pas de retrait du tout : une
/// surface d'API qui annonce encore la protection, un secret qui dort en base, et une
/// connexion qui ne le réclame plus, cela fait un contrôle de sécurité contourné en
/// silence.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class SansDoubleAuthentificationTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task La_connexion_ouvre_une_session_sans_etape_intermediaire()
    {
        using var client = fixture.CreateClient();
        var adresse = await InscrireAsync(client);

        var connexion = await client.PostAsJsonAsync(
            new Uri("/v1/auth/login", UriKind.Relative),
            new { email = adresse, password = MotDePasse });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = (await connexion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        // Une session complète, tout de suite.
        corps.GetProperty("accessToken").GetString().ShouldNotBeNullOrWhiteSpace();
        corps.GetProperty("refreshToken").GetString().ShouldNotBeNullOrWhiteSpace();

        // Et plus aucune trace du défi : un client qui lirait encore ces champs doit
        // échouer franchement à la compilation ou à la lecture, pas se fier à un
        // « false » qui laisserait croire que la protection existe et se trouve inactive.
        corps.TryGetProperty("requiresSecondFactor", out _).ShouldBeFalse();
        corps.TryGetProperty("challengeToken", out _).ShouldBeFalse();
        corps.TryGetProperty("challengeExpiresAt", out _).ShouldBeFalse();
    }

    [Theory]
    [InlineData("POST", "/v1/auth/mfa/verify")]
    [InlineData("POST", "/v1/auth/totp/setup")]
    [InlineData("POST", "/v1/auth/totp/activate")]
    [InlineData("DELETE", "/v1/auth/totp")]
    [InlineData("POST", "/v1/auth/totp/recovery-codes")]
    public async Task Les_endpoints_de_double_authentification_ont_disparu(
        string methode,
        string chemin)
    {
        using var client = fixture.CreateClient();
        var adresse = await InscrireAsync(client);
        var acces = await ConnecterAsync(client, adresse);

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        using var requete = new HttpRequestMessage(
            new HttpMethod(methode),
            new Uri(chemin, UriKind.Relative))
        {
            Content = JsonContent.Create(new { code = "000000", password = MotDePasse }),
        };

        var reponse = await authentifie.SendAsync(requete);

        // 404 et non 401 : la route n'existe plus. Un compte authentifié le vérifie —
        // un 401 sur un appel anonyme ne prouverait rien du retrait de la route.
        reponse.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Le_profil_ne_declare_plus_de_double_authentification()
    {
        using var client = fixture.CreateClient();
        var adresse = await InscrireAsync(client);
        var acces = await ConnecterAsync(client, adresse);

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        var profil = await authentifie.GetFromJsonAsync<JsonDocument>(
            new Uri("/v1/me", UriKind.Relative));

        profil!.RootElement.TryGetProperty("totpEnabled", out _).ShouldBeFalse();
    }

    [Fact]
    public async Task La_base_ne_porte_plus_ni_secret_ni_code_de_secours()
    {
        var colonnes = await CompterAsync(
            """
            SELECT COUNT(*)::int AS "Value" FROM information_schema.columns
            WHERE table_name = 'users'
              AND column_name IN ('totp_secret_encrypted', 'totp_enabled_at')
            """);

        var tables = await CompterAsync(
            """
            SELECT COUNT(*)::int AS "Value" FROM information_schema.tables
            WHERE table_name = 'totp_recovery_codes'
            """);

        // Un secret chiffré que plus aucun code ne lit reste une donnée personnelle
        // conservée sans finalité : la migration doit l'avoir emportée.
        colonnes.ShouldBe(0);
        tables.ShouldBe(0);
    }

    [Fact]
    public async Task Un_role_plateforme_est_accorde_sans_second_facteur()
    {
        using var client = fixture.CreateClient();

        var adresseAdmin = await InscrireAsync(client);
        var administrateur = await IdentifiantAsync(adresseAdmin);
        await PromouvoirEnBaseAsync(administrateur, PlatformRole.PlatformAdmin);

        var cible = await InscrireAsync(client);
        var identifiantCible = await IdentifiantAsync(cible);

        // Le rôle est porté par le jeton : la session doit être postérieure à la promotion.
        var acces = await ConnecterAsync(client, adresseAdmin);

        using var admin = fixture.CreateClient();
        admin.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        var promotion = await admin.PatchAsJsonAsync(
            new Uri($"/v1/admin/users/{identifiantCible}/role", UriKind.Relative),
            new { role = nameof(PlatformRole.PlatformAdmin), reason = "Astreinte" });

        // RG-ADM-04 est abrogée : la promotion aboutit alors que la cible n'a aucun
        // second facteur, ce qui était précisément le refus qui rendait l'administration
        // inatteignable.
        promotion.StatusCode.ShouldBeOneOf(HttpStatusCode.OK, HttpStatusCode.NoContent);
    }

    // ------------------------------------------------------------------ aides ----

    private static async Task<string> InscrireAsync(HttpClient client)
    {
        var adresse = $"sans2fa-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await client.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = adresse, password = MotDePasse, displayName = "Sans second facteur" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        return adresse;
    }

    private static async Task<string> ConnecterAsync(HttpClient client, string adresse)
    {
        var connexion = await client.PostAsJsonAsync(
            new Uri("/v1/auth/login", UriKind.Relative),
            new { email = adresse, password = MotDePasse });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = (await connexion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        return corps.GetProperty("accessToken").GetString()!;
    }

    private async Task<Guid> IdentifiantAsync(string adresse)
    {
        var identifiant = Guid.Empty;

        await fixture.WithDatabaseAsync(async db =>
            identifiant = (await db.Users
                .IgnoreQueryFilters()
                .SingleAsync(u => u.Email == adresse && u.DeletedAt == null)).Id);

        return identifiant;
    }

    private Task PromouvoirEnBaseAsync(Guid identifiant, PlatformRole role) =>
        fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.IgnoreQueryFilters().SingleAsync(u => u.Id == identifiant);
            compte.PlatformRole = role;
            await db.SaveChangesAsync();
        });

    private async Task<int> CompterAsync(string sql)
    {
        var compte = 0;

        await fixture.WithDatabaseAsync(async db =>
            compte = await db.Database.SqlQueryRaw<int>(sql).SingleAsync());

        return compte;
    }
}
