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
/// Attribution de la formule payante par un administrateur (EF-PRM-04, ADR 0008).
/// <para>
/// Seul moyen d'attribution jusqu'au lot 4.1 : aucun encaissement n'existe. Le rôle
/// Support en est exclu — RG-ADM-05 le borne à la consultation et au dépannage, et offrir
/// un abonnement n'est ni l'un ni l'autre.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class AttributionFormuleTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Un_administrateur_accorde_puis_retire_la_formule()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        var echeance = DateTimeOffset.UtcNow.AddDays(30);

        (await AccorderAsync(admin, cible, echeance, "Offert au client pilote"))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await EcheanceAsync(clientCible)).ShouldNotBeNull();

        (await RetirerAsync(admin, cible, "Fin de la période d'essai"))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await EcheanceAsync(clientCible)).ShouldBeNull();
    }

    [Fact]
    public async Task Le_role_support_est_refuse()
    {
        using var support = await CompteAvecRoleAsync(PlatformRole.Support);
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        (await AccorderAsync(support, cible, DateTimeOffset.UtcNow.AddDays(30), "Tentative"))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);

        (await RetirerAsync(support, cible, "Tentative"))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Un_compte_ordinaire_est_refuse()
    {
        var (_, ordinaire) = await CompteAsync();
        using var _1 = ordinaire;
        var (cible, clientCible) = await CompteAsync();
        using var _2 = clientCible;

        (await AccorderAsync(ordinaire, cible, DateTimeOffset.UtcNow.AddDays(30), "Tentative"))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);

        (await RetirerAsync(ordinaire, cible, "Tentative"))
            .StatusCode.ShouldBe(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Une_echeance_passee_est_refusee()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        var refus = await AccorderAsync(
            admin,
            cible,
            DateTimeOffset.UtcNow.AddDays(-1),
            "Échéance absurde");

        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await CodeAsync(refus)).ShouldBe("plan.expiry_in_past");
    }

    [Fact]
    public async Task Une_echeance_absente_est_refusee()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        var refus = await admin.PutAsJsonAsync(
            $"/v1/admin/users/{cible}/plan",
            new { reason = "Sans terme" });

        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await CodeAsync(refus)).ShouldBe("plan.expiry_required");
    }

    [Fact]
    public async Task Un_motif_absent_est_refuse()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        var accord = await AccorderAsync(admin, cible, DateTimeOffset.UtcNow.AddDays(30), motif: null);
        accord.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await CodeAsync(accord)).ShouldBe("plan.reason_required");

        var retrait = await RetirerAsync(admin, cible, motif: null);
        retrait.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await CodeAsync(retrait)).ShouldBe("plan.reason_required");
    }

    [Fact]
    public async Task Un_compte_inconnu_renvoie_introuvable()
    {
        using var admin = await AdministrateurAsync();

        (await AccorderAsync(
                admin,
                Guid.CreateVersion7(),
                DateTimeOffset.UtcNow.AddDays(30),
                "Compte fantôme"))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Chaque_changement_effectif_ecrit_une_ligne_d_audit()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        await AccorderAsync(admin, cible, DateTimeOffset.UtcNow.AddDays(30), "Octroi");
        await RetirerAsync(admin, cible, "Retrait");

        (await CompterAuditAsync(cible)).ShouldBe(2);
    }

    [Fact]
    public async Task Reappliquer_la_meme_echeance_n_ecrit_pas_d_audit()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        // L'échéance est fixée à la seconde près pour que les deux requêtes portent bien
        // la même valeur : sans cela, la comparaison porterait sur deux instants distincts.
        var echeance = new DateTimeOffset(2026, 12, 31, 23, 0, 0, TimeSpan.Zero);

        (await AccorderAsync(admin, cible, echeance, "Octroi")).StatusCode
            .ShouldBe(HttpStatusCode.NoContent);

        // Le back-office se manipule à la main : un double clic ne doit pas laisser deux
        // lignes identiques dans un journal inaltérable.
        (await AccorderAsync(admin, cible, echeance, "Octroi")).StatusCode
            .ShouldBe(HttpStatusCode.NoContent);

        (await CompterAuditAsync(cible)).ShouldBe(1);
    }

    [Fact]
    public async Task La_ligne_d_audit_resiste_a_la_modification()
    {
        using var admin = await AdministrateurAsync();
        var (cible, clientCible) = await CompteAsync();
        using var _ = clientCible;

        await AccorderAsync(admin, cible, DateTimeOffset.UtcNow.AddDays(30), "Octroi");

        // RG-ADM-06 et NF-SEC-08 : ni UPDATE ni DELETE, y compris pour un PlatformAdmin.
        await Should.ThrowAsync<Exception>(() => fixture.WithDatabaseAsync(async db =>
        {
            await db.Database.ExecuteSqlRawAsync(
                "UPDATE admin_audit_entries SET action = 'falsifie' WHERE target_user_id = {0}",
                cible);
        }));

        await Should.ThrowAsync<Exception>(() => fixture.WithDatabaseAsync(async db =>
        {
            await db.Database.ExecuteSqlRawAsync(
                "DELETE FROM admin_audit_entries WHERE target_user_id = {0}",
                cible);
        }));
    }

    // --------------------------------------------------------------- assistants ----

    private static Task<HttpResponseMessage> AccorderAsync(
        HttpClient client,
        Guid userId,
        DateTimeOffset echeance,
        string? motif) =>
        client.PutAsJsonAsync(
            $"/v1/admin/users/{userId}/plan",
            new { premiumUntil = echeance, reason = motif });

    /// <summary>
    /// Le motif voyage en chaîne de requête : un DELETE porteur d'un corps n'est pas
    /// inféré par les endpoints minimaux.
    /// </summary>
    private static Task<HttpResponseMessage> RetirerAsync(
        HttpClient client,
        Guid userId,
        string? motif)
    {
        var chemin = motif is null
            ? $"/v1/admin/users/{userId}/plan"
            : $"/v1/admin/users/{userId}/plan?reason={Uri.EscapeDataString(motif)}";

        return client.DeleteAsync(new Uri(chemin, UriKind.Relative));
    }

    private static async Task<DateTimeOffset?> EcheanceAsync(HttpClient client)
    {
        var profil = await client.GetFromJsonAsync<JsonDocument>("/v1/me");
        var champ = profil!.RootElement.GetProperty("premiumUntil");

        return champ.ValueKind == JsonValueKind.Null ? null : champ.GetDateTimeOffset();
    }

    private async Task<int> CompterAuditAsync(Guid cible)
    {
        var total = 0;

        await fixture.WithDatabaseAsync(async db =>
        {
            total = await db.AdminAuditEntries.CountAsync(
                e => e.TargetUserId == cible && e.Action == "user.plan_changed");
        });

        return total;
    }

    private static async Task<string?> CodeAsync(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }

    private async Task<HttpClient> AdministrateurAsync() =>
        await CompteAvecRoleAsync(PlatformRole.PlatformAdmin);

    /// <summary>
    /// Crée un compte, lui attribue un rôle plateforme, puis ouvre une session : le rôle
    /// est porté par le jeton, une session antérieure ne le connaîtrait pas.
    /// </summary>
    private async Task<HttpClient> CompteAvecRoleAsync(PlatformRole role)
    {
        var adresse = $"formule-adm-{Guid.CreateVersion7():N}@partyplan.test";
        var (userId, client) = await CompteAsync(adresse);
        client.Dispose();

        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Id == userId);
            compte.PlatformRole = role;
            await db.SaveChangesAsync();
        });

        using var anonyme = fixture.CreateClient();

        var session = await anonyme.PostAsJsonAsync(
            "/v1/auth/login",
            new { email = adresse, password = MotDePasse });

        session.StatusCode.ShouldBe(HttpStatusCode.OK);

        var acces = (await session.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        return authentifie;
    }

    private async Task<(Guid UserId, HttpClient Client)> CompteAsync(string? adresse = null)
    {
        adresse ??= $"formule-{Guid.CreateVersion7():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync(
            "/v1/auth/register",
            new { email = adresse, password = MotDePasse, displayName = "Cible" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        var profil = await client.GetFromJsonAsync<JsonDocument>("/v1/me");

        return (profil!.RootElement.GetProperty("id").GetGuid(), client);
    }
}
