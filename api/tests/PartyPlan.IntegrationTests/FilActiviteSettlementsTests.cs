namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Lignes de fil produites par le module Settlements (RG-FIL-01).
/// <para>
/// Le payload porte le débiteur <b>et</b> le créancier, pas seulement l'un des deux :
/// une personne qui gère l'événement peut marquer un remboursement entre deux autres,
/// et l'auteur de l'action ne suffit donc pas à savoir qui a réglé qui.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FilActiviteSettlementsTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Marquer_un_remboursement_consigne_les_deux_parties_et_le_montant()
    {
        var soiree = await DetteAsync();

        await MarquerAsync(soiree);

        var (ligne, donnees) = await fixture.UniqueActiviteAsync(
            soiree.EventId, ActivityKinds.SettlementMarked);

        ligne.ActorName.ShouldBe("Camille");
        donnees.Texte("de").ShouldBe("Organisateur");
        donnees.Texte("vers").ShouldBe("Camille");
        donnees.Montant("montant").ShouldBe(20m);
    }

    [Fact]
    public async Task Annuler_un_remboursement_le_consigne_aussi()
    {
        // Le cas qui fait le désaccord : quelqu'un annule un remboursement déjà marqué.
        // Sans cette ligne, le fil affirme que la dette a été réglée et se tait sur la
        // suite.
        var soiree = await DetteAsync();
        var reglementId = await MarquerAsync(soiree);

        (await soiree.Client.DeleteAsync(new Uri(
            $"/v1/events/{soiree.EventId}/settlements/{reglementId}", UriKind.Relative)))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            soiree.EventId, ActivityKinds.SettlementCancelled);

        donnees.Texte("de").ShouldBe("Organisateur");
        donnees.Texte("vers").ShouldBe("Camille");
        donnees.Montant("montant").ShouldBe(20m);
    }

    [Fact]
    public async Task Un_marquage_refuse_ne_laisse_aucune_ligne()
    {
        var soiree = await DetteAsync();

        // RG-RMB : un remboursement de soi vers soi n'existe pas.
        var refus = await soiree.Client.PosterAsync(
            $"/v1/events/{soiree.EventId}/settlements",
            new
            {
                fromMemberId = soiree.CamilleId,
                toMemberId = soiree.CamilleId,
                amount = 10m,
            });

        refus.IsSuccessStatusCode.ShouldBeFalse();
        (await fixture.ActivitesAsync(soiree.EventId, ActivityKinds.SettlementMarked))
            .ShouldBeEmpty();
    }

    private static async Task<string> MarquerAsync(Soiree soiree)
    {
        var marquage = await soiree.Client.PosterAsync(
            $"/v1/events/{soiree.EventId}/settlements",
            new
            {
                fromMemberId = soiree.AlexId,
                toMemberId = soiree.CamilleId,
                amount = 20m,
            });

        marquage.EnsureSuccessStatusCode();

        var page = (await marquage.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        return page.GetProperty("done").EnumerateArray().First()
            .GetProperty("id").GetString()!;
    }

    /// <summary>
    /// Une soirée où Camille a avancé 40 € partagés à deux : le créateur lui doit 20 €.
    /// <para>
    /// Le membre créateur s'appelle « Organisateur » — un nom posé en dur par le module
    /// Events, indépendamment du profil. Le test le constate plutôt que de le masquer.
    /// </para>
    /// </summary>
    private async Task<Soiree> DetteAsync()
    {
        var alex = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await alex.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        var membres = await camille.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var lignes = membres!.RootElement.EnumerateArray().ToList();
        var camilleId = lignes.First(m => m.GetProperty("displayName").GetString() == "Camille")
            .GetProperty("id").GetString()!;
        var alexId = lignes.First(m => m.GetProperty("id").GetString() != camilleId)
            .GetProperty("id").GetString()!;

        (await camille.PosterAsync(
            $"/v1/events/{eventId}/expenses",
            new { label = "Courses", amount = 40m })).EnsureSuccessStatusCode();

        return new Soiree(camille, eventId, alexId, camilleId);
    }

    private sealed record Soiree(
        HttpClient Client,
        string EventId,
        string AlexId,
        string CamilleId);
}
