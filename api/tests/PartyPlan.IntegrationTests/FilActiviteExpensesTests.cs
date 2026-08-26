namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Lignes de fil produites par le module Expenses (RG-FIL-01).
/// <para>
/// La modification porte l'ancien montant autant que le nouveau : « combien c'était
/// avant » est la question posée en cas de désaccord, et la réponse doit se lire sans
/// ouvrir la table des révisions.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FilActiviteExpensesTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Creer_une_depense_consigne_libelle_et_montant()
    {
        var (client, eventId) = await SoireeAsync();

        await CreerDepenseAsync(client, eventId, "Courses", 62.40m);

        var (ligne, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ExpenseCreated);

        ligne.ActorName.ShouldBe("Camille");
        donnees.Texte("libelle").ShouldBe("Courses");
        donnees.Montant("montant").ShouldBe(62.40m);
    }

    [Fact]
    public async Task Modifier_une_depense_consigne_l_ancien_et_le_nouveau_montant()
    {
        var (client, eventId) = await SoireeAsync();
        var depenseId = await CreerDepenseAsync(client, eventId, "Courses", 62.40m);

        (await client.PatchAsJsonAsync(
            $"/v1/events/{eventId}/expenses/{depenseId}",
            new { label = "Courses", amount = 58.10m }))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ExpenseUpdated);

        donnees.Montant("ancienMontant").ShouldBe(62.40m);
        donnees.Montant("montant").ShouldBe(58.10m);
    }

    [Fact]
    public async Task Supprimer_une_depense_consigne_sa_disparition()
    {
        // Le cas le plus sensible du lot : une dépense qui s'efface change les soldes
        // de tout le monde. Le fil doit en garder trace.
        var (client, eventId) = await SoireeAsync();
        var depenseId = await CreerDepenseAsync(client, eventId, "Courses", 62.40m);

        (await client.DeleteAsync(new Uri(
            $"/v1/events/{eventId}/expenses/{depenseId}", UriKind.Relative)))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ExpenseDeleted);

        donnees.Texte("libelle").ShouldBe("Courses");
        donnees.Montant("montant").ShouldBe(62.40m);
    }

    [Fact]
    public async Task Une_depense_refusee_ne_laisse_aucune_ligne()
    {
        var (client, eventId) = await SoireeAsync();

        // RG-DEP-01 : montant strictement positif.
        var refus = await client.PosterAsync(
            $"/v1/events/{eventId}/expenses",
            new { label = "Impossible", amount = 0m });

        refus.IsSuccessStatusCode.ShouldBeFalse();
        (await fixture.ActivitesAsync(eventId, ActivityKinds.ExpenseCreated)).ShouldBeEmpty();
    }

    private async Task<(HttpClient Client, string EventId)> SoireeAsync()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await organisateur.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        return (camille, eventId);
    }

    private static async Task<string> CreerDepenseAsync(
        HttpClient client,
        string eventId,
        string libelle,
        decimal montant)
    {
        var creation = await client.PosterAsync(
            $"/v1/events/{eventId}/expenses",
            new { label = libelle, amount = montant });

        creation.EnsureSuccessStatusCode();

        return (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;
    }
}
