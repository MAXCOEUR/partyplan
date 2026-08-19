namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Auth.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Parcours complet de double authentification (EF-AUTH-12, RG-ADM-04).
/// <para>
/// Tout passe par l'API réelle : enrôlement, activation, connexion en deux temps, codes
/// de secours. Un test qui court-circuiterait la vérification ne prouverait rien sur la
/// protection effective.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class DoubleAuthentificationTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Le_parcours_complet_d_enrolement_fonctionne()
    {
        var (client, adresse) = await CompteAsync();

        // 1. Enrôlement : un secret est remis, mais rien n'est encore actif.
        var enrolement = await client.PostAsync(new Uri("/v1/auth/totp/setup", UriKind.Relative), null);
        enrolement.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = (await enrolement.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        var secretBase32 = corps.GetProperty("secret").GetString()!;
        var uri = corps.GetProperty("otpAuthUri").GetString()!;

        uri.ShouldStartWith("otpauth://totp/");
        uri.ShouldContain("period=30");

        Base32.TryDecode(secretBase32, out var secret).ShouldBeTrue();

        // Tant que l'activation n'a pas eu lieu, la connexion reste en un temps :
        // l'inverse enfermerait dehors quiconque a mal scanné le QR code.
        var profilAvant = await client.GetFromJsonAsync<JsonDocument>("/v1/me");
        profilAvant!.RootElement.GetProperty("totpEnabled").GetBoolean().ShouldBeFalse();

        // 2. Un code erroné n'active rien.
        var refus = await client.PostAsJsonAsync("/v1/auth/totp/activate", new { code = "000000" });
        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(refus)).ShouldBe("totp.invalid_code");

        // 3. Activation avec un code valide : les codes de secours sont remis.
        var activation = await client.PostAsJsonAsync(
            "/v1/auth/totp/activate",
            new { code = Totp.Compute(secret, DateTimeOffset.UtcNow) });

        activation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var codes = (await activation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("recoveryCodes")
            .EnumerateArray()
            .Select(c => c.GetString()!)
            .ToList();

        // Sans codes de secours, un téléphone perdu enfermerait définitivement dehors.
        codes.Count.ShouldBe(8);
        codes.ShouldAllBe(c => c.Length == 9 && c[4] == '-');
        codes.Distinct().Count().ShouldBe(codes.Count);

        var profilApres = await client.GetFromJsonAsync<JsonDocument>("/v1/me");
        profilApres!.RootElement.GetProperty("totpEnabled").GetBoolean().ShouldBeTrue();

        // 4. La connexion se fait désormais en deux temps.
        using var anonyme = fixture.CreateClient();

        var premiere = await anonyme.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = MotDePasse,
        });

        var reponse = (await premiere.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        reponse.GetProperty("requiresSecondFactor").GetBoolean().ShouldBeTrue();
        reponse.GetProperty("accessToken").ValueKind.ShouldBe(JsonValueKind.Null);
        reponse.GetProperty("refreshToken").ValueKind.ShouldBe(JsonValueKind.Null);

        var defi = reponse.GetProperty("challengeToken").GetString()!;

        // 5. Le jeton de défi n'est pas un jeton d'accès : audience distincte.
        using var avecDefi = fixture.CreateClient();
        avecDefi.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", defi);

        (await avecDefi.GetAsync(new Uri("/v1/me", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);

        // 6. Un code erroné ne franchit pas la seconde étape.
        var mauvais = await anonyme.PostAsJsonAsync("/v1/auth/mfa/verify", new
        {
            challengeToken = defi,
            code = "000000",
        });

        mauvais.StatusCode.ShouldBe(HttpStatusCode.BadRequest);

        // 7. Le bon code ouvre la session.
        var seconde = await anonyme.PostAsJsonAsync("/v1/auth/mfa/verify", new
        {
            challengeToken = defi,
            code = Totp.Compute(secret, DateTimeOffset.UtcNow),
        });

        seconde.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await seconde.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString().ShouldNotBeNullOrEmpty();
    }

    [Fact]
    public async Task Un_code_de_secours_remplace_le_code_temporel_et_ne_sert_qu_une_fois()
    {
        var (client, adresse) = await CompteAsync();
        var (secret, codes) = await ActiverAsync(client);

        var codeDeSecours = codes[0];

        using var anonyme = fixture.CreateClient();

        var defi = await DefiAsync(anonyme, adresse);

        var premiere = await anonyme.PostAsJsonAsync("/v1/auth/mfa/verify", new
        {
            challengeToken = defi,
            code = codeDeSecours,
        });

        premiere.StatusCode.ShouldBe(HttpStatusCode.OK);

        // Usage unique : un code de secours réutilisable perdrait tout intérêt s'il
        // était intercepté.
        var secondDefi = await DefiAsync(anonyme, adresse);

        var rejeu = await anonyme.PostAsJsonAsync("/v1/auth/mfa/verify", new
        {
            challengeToken = secondDefi,
            code = codeDeSecours,
        });

        rejeu.StatusCode.ShouldBe(HttpStatusCode.BadRequest);

        // Les autres codes du lot restent valides.
        var troisiemeDefi = await DefiAsync(anonyme, adresse);

        var autre = await anonyme.PostAsJsonAsync("/v1/auth/mfa/verify", new
        {
            challengeToken = troisiemeDefi,
            code = codes[1],
        });

        autre.StatusCode.ShouldBe(HttpStatusCode.OK);
        secret.ShouldNotBeEmpty();
    }

    [Fact]
    public async Task La_desactivation_exige_le_mot_de_passe()
    {
        var (client, _) = await CompteAsync();
        await ActiverAsync(client);

        using var mauvais = new HttpRequestMessage(
            HttpMethod.Delete,
            new Uri("/v1/auth/totp", UriKind.Relative))
        {
            Content = JsonContent.Create(new { password = "Cerf-Volant-Ocre-91" }),
        };

        var refus = await client.SendAsync(mauvais);

        // Sans cette exigence, un jeton volé suffirait à retirer le second facteur.
        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(refus)).ShouldBe("user.wrong_password");

        using var bon = new HttpRequestMessage(
            HttpMethod.Delete,
            new Uri("/v1/auth/totp", UriKind.Relative))
        {
            Content = JsonContent.Create(new { password = MotDePasse }),
        };

        (await client.SendAsync(bon)).StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var profil = await client.GetFromJsonAsync<JsonDocument>("/v1/me");
        profil!.RootElement.GetProperty("totpEnabled").GetBoolean().ShouldBeFalse();
    }

    [Fact]
    public async Task La_regeneration_invalide_les_codes_precedents()
    {
        var (client, adresse) = await CompteAsync();
        var (_, anciens) = await ActiverAsync(client);

        var nouveaux = await client.PostAsync(
            new Uri("/v1/auth/totp/recovery-codes", UriKind.Relative),
            null);

        nouveaux.StatusCode.ShouldBe(HttpStatusCode.OK);

        var lot = (await nouveaux.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("recoveryCodes")
            .EnumerateArray()
            .Select(c => c.GetString()!)
            .ToList();

        lot.ShouldNotBe(anciens);

        using var anonyme = fixture.CreateClient();
        var defi = await DefiAsync(anonyme, adresse);

        var ancien = await anonyme.PostAsJsonAsync("/v1/auth/mfa/verify", new
        {
            challengeToken = defi,
            code = anciens[0],
        });

        // Régénérer sans invalider laisserait deux lots valides en circulation.
        ancien.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Un_deuxieme_enrolement_est_refuse_lorsque_le_facteur_est_actif()
    {
        var (client, _) = await CompteAsync();
        await ActiverAsync(client);

        var reponse = await client.PostAsync(new Uri("/v1/auth/totp/setup", UriKind.Relative), null);

        // Sans ce refus, un jeton volé pourrait remplacer le second facteur par le sien.
        reponse.StatusCode.ShouldBe(HttpStatusCode.Conflict);
        (await Code(reponse)).ShouldBe("totp.already_enabled");
    }

    private async Task<(HttpClient client, string adresse)> CompteAsync()
    {
        var adresse = $"totp-{Guid.CreateVersion7():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = MotDePasse,
            displayName = "Test TOTP",
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        return (client, adresse);
    }

    private static async Task<(byte[] secret, List<string> codes)> ActiverAsync(HttpClient client)
    {
        var enrolement = await client.PostAsync(new Uri("/v1/auth/totp/setup", UriKind.Relative), null);

        var secretBase32 = (await enrolement.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("secret").GetString()!;

        Base32.TryDecode(secretBase32, out var secret);

        var activation = await client.PostAsJsonAsync(
            "/v1/auth/totp/activate",
            new { code = Totp.Compute(secret, DateTimeOffset.UtcNow) });

        activation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var codes = (await activation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("recoveryCodes")
            .EnumerateArray()
            .Select(c => c.GetString()!)
            .ToList();

        return (secret, codes);
    }

    private static async Task<string> DefiAsync(HttpClient client, string adresse)
    {
        var reponse = await client.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = MotDePasse,
        });

        return (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("challengeToken").GetString()!;
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }
}
