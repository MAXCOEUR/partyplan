namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using Shouldly;
using Xunit;

/// <summary>
/// Lignes de fil produites par le module Events (RG-FIL-01) : arrivée d'un membre,
/// changement de statut, modification de la date ou du lieu.
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FilActiviteEventsTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Rejoindre_consigne_l_arrivee_du_membre()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await organisateur.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        var arrivees = await fixture.ActivitesAsync(eventId, ActivityKinds.MemberJoined);
        arrivees.ShouldContain(a => a.ActorName == "Camille");
        arrivees.Single(a => a.ActorName == "Camille").Payload.ShouldBeNull();
    }

    [Fact]
    public async Task Changer_de_statut_consigne_l_ancien_et_le_nouveau()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await organisateur.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        (await camille.PatchAsJsonAsync(
                $"/v1/events/{eventId}/members/me",
                new { status = "Going" }))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.MemberStatusChanged);

        donnees.Texte("de").ShouldBe("Unknown");
        donnees.Texte("vers").ShouldBe("Going");
    }

    [Fact]
    public async Task Changer_la_date_consigne_le_champ_touche()
    {
        // Sans ce payload, l'application ne peut pas distinguer un changement de date
        // d'un changement de lieu : les deux n'en font qu'un à l'affichage.
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, _) = await organisateur.CreerEvenementAsync();

        (await organisateur.PatchAsJsonAsync(
                $"/v1/events/{eventId}",
                new { name = "Soirée du fil", startsAt = DateTimeOffset.UtcNow.AddDays(9) }))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.EventDateOrPlaceChanged);

        donnees.Liste("champs").ShouldBe(["date"]);
    }

    [Fact]
    public async Task Changer_le_lieu_consigne_le_lieu_et_non_la_date()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, _) = await organisateur.CreerEvenementAsync();

        (await organisateur.PatchAsJsonAsync(
                $"/v1/events/{eventId}",
                new { name = "Soirée du fil", address = "12 rue des Lilas, Lyon" }))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.EventDateOrPlaceChanged);

        donnees.Liste("champs").ShouldBe(["lieu"]);
    }
}
