namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Déclencheurs de la liste de courses.
/// <para>
/// La prise en charge et l'achat prévenaient déjà les autres membres. L'ajout, non :
/// quelqu'un qui pose « il manque du pain » sur la liste ne prévenait personne, et
/// l'article restait à prendre en charge parce que personne ne savait qu'il existait.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class NotificationsCoursesTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    private Guid _evenement;
    private Membre _hote = null!;
    private Membre _lucas = null!;

    public async Task InitializeAsync()
    {
        var (hote, _) = await fixture.CompteAvecJetonAsync("Camille");
        var (eventId, jetonInvitation) = await hote.CreerEvenementAsync("Soirée des courses");
        _evenement = Guid.Parse(eventId);

        var lucas = await fixture.CompteAsync("Lucas");
        await lucas.RejoindreAsync(jetonInvitation);

        _hote = await MembreAsync("Organisateur", hote);
        _lucas = await MembreAsync("Lucas", lucas);
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Un_article_ajoute_previent_les_autres_membres()
    {
        await AjouterArticleAsync(_hote, "Pain");

        var notifs = await NotificationsAsync();

        notifs.ShouldContain(n => n.UserId == _lucas.UserId
            && n.Category == NotificationCategories.Activity);
    }

    [Fact]
    public async Task L_auteur_de_l_ajout_n_est_pas_prevenu()
    {
        // Être averti de son propre geste est du bruit, et le bruit fait couper la
        // catégorie entière.
        await AjouterArticleAsync(_hote, "Pain");

        var notifs = await NotificationsAsync();

        notifs.ShouldNotContain(n => n.UserId == _hote.UserId);
    }

    [Fact]
    public async Task La_notification_d_ajout_nomme_l_article_et_son_auteur()
    {
        await AjouterArticleAsync(_hote, "Pain");

        var notifs = await NotificationsAsync();

        notifs.ShouldContain(n => n.Body.Contains("Pain", StringComparison.Ordinal));
    }

    [Fact]
    public async Task La_notification_d_ajout_ouvre_l_onglet_des_courses()
    {
        await AjouterArticleAsync(_hote, "Pain");

        var notifs = await NotificationsAsync();

        notifs.ShouldAllBe(n => n.DeepLink == $"/events/{_evenement}/courses");
    }

    [Fact]
    public async Task Deux_articles_ajoutes_donnent_deux_notifications()
    {
        // La clé de déduplication porte l'article : deux ajouts distincts ne doivent pas
        // se confondre, sinon le second serait refusé par la base et perdu.
        await AjouterArticleAsync(_hote, "Pain");
        await AjouterArticleAsync(_hote, "Fromage");

        var notifs = await NotificationsAsync();

        notifs.Count(n => n.UserId == _lucas.UserId).ShouldBe(2);
    }

    // ------------------------------------------------------------------ aides ----

    private async Task<Membre> MembreAsync(string displayName, HttpClient client)
    {
        var memberId = Guid.Empty;
        var compte = Guid.Empty;

        await fixture.WithDatabaseAsync(async db =>
        {
            var membre = await db.EventMembers
                .IgnoreQueryFilters()
                .Where(m => m.EventId == _evenement && m.DisplayName == displayName)
                .SingleAsync();

            memberId = membre.Id;
            compte = membre.UserId!.Value;
        });

        return new Membre(memberId, compte, client);
    }

    private async Task AjouterArticleAsync(Membre auteur, string nom)
    {
        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/events/{_evenement}/shopping", UriKind.Relative))
        {
            Content = JsonContent.Create(new { name = nom, quantity = 1 }),
        };

        // L'ajout d'un article exige une clé d'idempotence : un double appui ne doit pas
        // poser deux fois le même article sur la liste.
        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        var reponse = await auteur.Client.SendAsync(requete);

        reponse.EnsureSuccessStatusCode();
    }

    private Task<List<Notification>> NotificationsAsync() =>
        fixture.NotificationsAsync(_evenement.ToString());

    private sealed record Membre(Guid MemberId, Guid UserId, HttpClient Client);
}
