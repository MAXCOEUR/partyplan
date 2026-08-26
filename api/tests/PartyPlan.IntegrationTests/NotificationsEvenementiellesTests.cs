namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Notifications nées d'une action (EF-NOT-01, EF-NOT-02).
/// <para>
/// Personne ne se notifie soi-même : celui qui agit sait ce qu'il vient de faire, et
/// recevoir l'écho de son propre geste est le défaut le plus sûr pour faire couper les
/// notifications.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class NotificationsEvenementiellesTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task EF_NOT_01_une_reponse_previent_l_organisateur()
    {
        var (organisateur, camille, eventId) = await SoireeADeuxAsync();

        (await camille.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Going" })).EnsureSuccessStatusCode();

        var avis = (await fixture.NotificationsAsync(
            eventId, NotificationCategories.InvitationAnswer)).ShouldHaveSingleItem();

        avis.UserId.ShouldBe(await fixture.ProprietaireAsync(eventId));
        avis.Body.ShouldContain("Camille");

        // L'organisateur n'a rien fait : c'est bien lui qu'on prévient.
        organisateur.ShouldNotBeNull();
    }

    [Fact]
    public async Task EF_NOT_01_celui_qui_repond_ne_se_notifie_pas()
    {
        var (_, camille, eventId) = await SoireeADeuxAsync();
        var compteCamille = await fixture.CompteDuMembreAsync(eventId, "Camille");

        (await camille.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Going" })).EnsureSuccessStatusCode();

        var avis = await fixture.NotificationsAsync(
            eventId, NotificationCategories.InvitationAnswer);

        avis.ShouldNotContain(n => n.UserId == compteCamille);
    }

    [Fact]
    public async Task EF_NOT_01_repondre_deux_fois_le_meme_statut_ne_previent_qu_une_fois()
    {
        var (_, camille, eventId) = await SoireeADeuxAsync();

        (await camille.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Going" })).EnsureSuccessStatusCode();
        (await camille.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Going" })).EnsureSuccessStatusCode();

        (await fixture.NotificationsAsync(
            eventId, NotificationCategories.InvitationAnswer)).Count.ShouldBe(1);
    }

    [Fact]
    public async Task EF_NOT_01_changer_d_avis_previent_de_nouveau()
    {
        // Passer de « oui » à « non » est exactement ce que l'organisateur doit savoir.
        // La clé de déduplication porte donc le statut, pas seulement le membre.
        var (_, camille, eventId) = await SoireeADeuxAsync();

        (await camille.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Going" })).EnsureSuccessStatusCode();
        (await camille.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "NotGoing" })).EnsureSuccessStatusCode();

        (await fixture.NotificationsAsync(
            eventId, NotificationCategories.InvitationAnswer)).Count.ShouldBe(2);
    }

    [Fact]
    public async Task EF_NOT_02_un_changement_de_date_previent_les_membres()
    {
        var (organisateur, _, eventId) = await SoireeADeuxAsync();
        var compteCamille = await fixture.CompteDuMembreAsync(eventId, "Camille");
        var proprietaire = await fixture.ProprietaireAsync(eventId);

        (await organisateur.PatchAsJsonAsync(
            $"/v1/events/{eventId}",
            new { name = "Soirée du fil", startsAt = DateTimeOffset.UtcNow.AddDays(9) }))
            .EnsureSuccessStatusCode();

        var avis = await fixture.NotificationsAsync(
            eventId, NotificationCategories.EventChanged);

        avis.ShouldContain(n => n.UserId == compteCamille);

        // Pas à l'auteur du changement : il vient de le faire.
        avis.ShouldNotContain(n => n.UserId == proprietaire);
    }

    [Fact]
    public async Task Une_modification_refusee_ne_laisse_aucune_notification()
    {
        // La garantie de transaction, éprouvée sur un vrai service : un nom vide est
        // rejeté par la validation, et rien ne doit rester en file.
        var (organisateur, _, eventId) = await SoireeADeuxAsync();

        var refus = await organisateur.PatchAsJsonAsync(
            $"/v1/events/{eventId}",
            new { name = "   ", startsAt = DateTimeOffset.UtcNow.AddDays(9) });

        refus.IsSuccessStatusCode.ShouldBeFalse();
        (await fixture.NotificationsAsync(
            eventId, NotificationCategories.EventChanged)).ShouldBeEmpty();
    }

    private async Task<(HttpClient Organisateur, HttpClient Camille, string EventId)>
        SoireeADeuxAsync()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await organisateur.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        return (organisateur, camille, eventId);
    }
}
