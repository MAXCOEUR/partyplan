namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Notification d'activité (EF-NOT-10).
/// <para>
/// RG-NOT-02 amendée le 30/08/2026 : le serveur ne plafonne plus les notifications
/// d'activité. Chaque geste produit la sienne, et c'est la clé de groupe de l'appareil
/// qui les empile sous un seul bandeau.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class RegroupementActiviteTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Prendre_un_article_previent_les_autres_membres()
    {
        var soiree = await SoireeADeuxAsync();
        var article = await AjouterAsync(soiree.Camille, soiree.EventId, "Glaçons");

        (await soiree.Camille.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping/{article}/claim"))
            .EnsureSuccessStatusCode();

        var avis = await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.Activity);

        avis.ShouldContain(n => n.UserId == soiree.CompteAlex);
    }

    [Fact]
    public async Task Celui_qui_prend_l_article_ne_se_notifie_pas()
    {
        var soiree = await SoireeADeuxAsync();
        var article = await AjouterAsync(soiree.Camille, soiree.EventId, "Glaçons");

        (await soiree.Camille.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping/{article}/claim"))
            .EnsureSuccessStatusCode();

        (await fixture.NotificationsAsync(soiree.EventId, NotificationCategories.Activity))
            .ShouldNotContain(n => n.UserId == soiree.CompteCamille);
    }

    [Fact]
    public async Task Deux_articles_pris_coup_sur_coup_font_deux_notifications()
    {
        // RG-NOT-02 amendée le 30/08/2026 : le serveur ne plafonne plus. On remplit une
        // liste, on prend deux choses d'affilée, et le voisin reçoit un avis par geste —
        // c'est l'appareil qui les empilera sous un seul bandeau.
        var soiree = await SoireeADeuxAsync();

        var premier = await AjouterAsync(soiree.Camille, soiree.EventId, "Glaçons");
        var second = await AjouterAsync(soiree.Camille, soiree.EventId, "Chips");

        (await soiree.Camille.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping/{premier}/claim"))
            .EnsureSuccessStatusCode();
        (await soiree.Camille.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping/{second}/claim"))
            .EnsureSuccessStatusCode();

        (await fixture.NotificationsAsync(soiree.EventId, NotificationCategories.Activity))
            .Count(n => n.UserId == soiree.CompteAlex)
            .ShouldBe(2);
    }

    [Fact]
    public async Task Acheter_un_article_previent_les_autres_membres()
    {
        var soiree = await SoireeADeuxAsync();
        var article = await AjouterAsync(soiree.Camille, soiree.EventId, "Bières");

        (await soiree.Camille.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping/{article}/purchase",
            new { actualPrice = 21.60m }))
            .EnsureSuccessStatusCode();

        var avis = await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.Activity);

        avis.ShouldContain(n => n.UserId == soiree.CompteAlex);
    }

    [Fact]
    public async Task Celui_qui_achete_ne_se_notifie_pas()
    {
        var soiree = await SoireeADeuxAsync();
        var article = await AjouterAsync(soiree.Camille, soiree.EventId, "Bières");

        (await soiree.Camille.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping/{article}/purchase",
            new { actualPrice = 21.60m }))
            .EnsureSuccessStatusCode();

        (await fixture.NotificationsAsync(soiree.EventId, NotificationCategories.Activity))
            .ShouldNotContain(n => n.UserId == soiree.CompteCamille);
    }

    private async Task<Soiree> SoireeADeuxAsync()
    {
        var alex = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await alex.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        return new Soiree(
            camille,
            eventId,
            await fixture.ProprietaireAsync(eventId),
            await fixture.CompteDuMembreAsync(eventId, "Camille"));
    }

    private static async Task<string> AjouterAsync(
        HttpClient client,
        string eventId,
        string libelle)
    {
        var creation = await client.PosterAsync(
            $"/v1/events/{eventId}/shopping",
            new { name = libelle });

        creation.EnsureSuccessStatusCode();

        return (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;
    }

    private sealed record Soiree(
        HttpClient Camille,
        string EventId,
        Guid CompteAlex,
        Guid CompteCamille);
}
