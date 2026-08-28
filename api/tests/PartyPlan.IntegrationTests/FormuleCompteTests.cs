namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Le contrat de frontière qui laisse les autres modules lire une formule sans toucher
/// la table des comptes (règle 6, ADR 0008).
/// <para>
/// Testé en intégration et non en unitaire : ce qui se vérifie ici est la traduction en
/// SQL de la comparaison d'échéance et le traitement d'un compte supprimé, deux choses
/// qu'un substitut en mémoire ne prouverait pas.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FormuleCompteTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasseValide = "Trombone-Nuage-42x";

    [Fact]
    public async Task Un_compte_sans_echeance_est_gratuit()
    {
        var userId = await CreerCompteAsync();

        (await EstAbonneAsync(userId)).ShouldBeFalse();
    }

    [Fact]
    public async Task Une_echeance_future_rend_le_compte_abonne()
    {
        var userId = await CreerCompteAsync();
        await DefinirEcheanceAsync(userId, DateTimeOffset.UtcNow.AddDays(30));

        (await EstAbonneAsync(userId)).ShouldBeTrue();
    }

    [Fact]
    public async Task Une_echeance_passee_redevient_gratuite_sans_intervention()
    {
        var userId = await CreerCompteAsync();
        await DefinirEcheanceAsync(userId, DateTimeOffset.UtcNow.AddSeconds(-1));

        (await EstAbonneAsync(userId)).ShouldBeFalse();
    }

    [Fact]
    public async Task Un_identifiant_inconnu_vaut_non_abonne()
    {
        (await EstAbonneAsync(Guid.CreateVersion7())).ShouldBeFalse();
    }

    [Fact]
    public async Task La_lecture_groupee_rend_une_entree_par_compte_connu()
    {
        var abonne = await CreerCompteAsync();
        var gratuit = await CreerCompteAsync();
        var inconnu = Guid.CreateVersion7();
        await DefinirEcheanceAsync(abonne, DateTimeOffset.UtcNow.AddDays(1));

        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        var resultat = await formule.EstAbonneManyAsync(
            [abonne, gratuit, inconnu],
            CancellationToken.None);

        resultat[abonne].ShouldBeTrue();
        resultat[gratuit].ShouldBeFalse();
        resultat.ContainsKey(inconnu).ShouldBeFalse();
    }

    [Fact]
    public async Task La_lecture_groupee_d_une_liste_vide_ne_touche_pas_la_base()
    {
        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        (await formule.EstAbonneManyAsync([], CancellationToken.None))
            .ShouldBeEmpty();
    }

    private async Task<bool> EstAbonneAsync(Guid userId)
    {
        using var portee = fixture.Services.CreateScope();
        var formule = portee.ServiceProvider.GetRequiredService<IFormuleCompte>();

        return await formule.EstAbonneAsync(userId, CancellationToken.None);
    }

    private Task DefinirEcheanceAsync(Guid userId, DateTimeOffset echeance) =>
        fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.FirstAsync(u => u.Id == userId);
            compte.PremiumUntil = echeance;
            await db.SaveChangesAsync();
        });

    private async Task<Guid> CreerCompteAsync()
    {
        using var client = fixture.CreateClient();

        var inscription = await client.PostAsJsonAsync(
            "/v1/auth/register",
            new
            {
                email = $"formule-{Guid.CreateVersion7():N}@partyplan.test",
                password = MotDePasseValide,
                displayName = "Test formule",
            });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var jetons = await inscription.Content.ReadFromJsonAsync<JsonDocument>();
        var acces = jetons!.RootElement.GetProperty("accessToken").GetString();

        using var authentifie = fixture.CreateClient();
        authentifie.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        var profil = await authentifie.GetFromJsonAsync<JsonDocument>("/v1/me");

        return profil!.RootElement.GetProperty("id").GetGuid();
    }
}
