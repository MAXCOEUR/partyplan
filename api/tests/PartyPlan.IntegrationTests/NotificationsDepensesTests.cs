namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Notifications.Domain;
using Shouldly;
using Xunit;

/// <summary>
/// Déclencheur des dépenses (tâche 6 du lot notifications) : une dépense créée prévient
/// ceux qui en portent une part, et eux seuls.
/// <para>
/// La soirée compte trois membres : <see cref="_maxence"/> qui paie et participe,
/// <see cref="_lucas"/> qui participe et reçoit, et <see cref="_emma"/> qui ne porte
/// aucune part — présente uniquement pour vérifier qu'elle n'est jamais notifiée d'une
/// dépense qui ne la concerne pas.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class NotificationsDepensesTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    private Guid _evenement;
    private Membre _maxence = null!;
    private Membre _lucas = null!;
    private Membre _emma = null!;

    public async Task InitializeAsync()
    {
        var (hote, _) = await fixture.CompteAvecJetonAsync("Camille");
        var (eventId, jetonInvitation) = await hote.CreerEvenementAsync("Soirée des dépenses");
        _evenement = Guid.Parse(eventId);

        var lucas = await fixture.CompteAsync("Lucas");
        await lucas.RejoindreAsync(jetonInvitation);

        var emma = await fixture.CompteAsync("Emma");
        await emma.RejoindreAsync(jetonInvitation);

        // Le créateur d'un événement porte toujours « Organisateur » comme nom de membre,
        // distinct du nom de son compte (EventService.CreerAsync).
        _maxence = await MembreAsync("Organisateur", hote);
        _lucas = await MembreAsync("Lucas", lucas);
        _emma = await MembreAsync("Emma", emma);
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Une_depense_ne_notifie_que_les_porteurs_d_une_part()
    {
        // Être averti d'une dépense dont on ne porte aucune part est du bruit, et le
        // bruit fait couper la catégorie entière.
        await CreerDepenseAsync(_maxence, "Courses", 40m, participants: [_maxence.MemberId, _lucas.MemberId]);

        var notifs = await NotificationsAsync();

        notifs.ShouldContain(n => n.UserId == _lucas.UserId);
        notifs.ShouldNotContain(n => n.UserId == _emma.UserId);
    }

    [Fact]
    public async Task Une_notification_de_depense_ouvre_l_onglet_des_depenses()
    {
        // La destination désigne l'onglet, pas seulement la soirée : on tape une
        // notification de dépense pour voir la dépense, pas le tableau de bord.
        await CreerDepenseAsync(_maxence, "Courses", 40m, participants: [_maxence.MemberId, _lucas.MemberId]);

        var notifs = await NotificationsAsync();

        notifs.ShouldAllBe(n => n.DeepLink == $"/events/{_evenement}/depenses");
    }

    [Fact]
    public async Task Le_payeur_n_est_pas_notifie_de_sa_propre_depense()
    {
        await CreerDepenseAsync(_maxence, "Courses", 40m, participants: [_maxence.MemberId, _lucas.MemberId]);

        var notifs = await NotificationsAsync();

        notifs.ShouldNotContain(n => n.UserId == _maxence.UserId);
    }

    [Fact]
    public async Task Une_depense_saisie_pour_un_autre_notifie_le_payeur_pas_l_auteur()
    {
        // Lucas saisit une dépense payée par Maxence : c'est Lucas qui a agi, c'est donc
        // lui qu'il faut exclure, jamais le payeur désigné qui, lui, doit être prévenu.
        await CreerDepenseAsync(
            _lucas,
            "Essence",
            30m,
            participants: [_maxence.MemberId, _lucas.MemberId],
            paidByMemberId: _maxence.MemberId);

        var notifs = await NotificationsAsync();

        notifs.ShouldContain(n => n.UserId == _maxence.UserId);
        notifs.ShouldNotContain(n => n.UserId == _lucas.UserId);
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

    private async Task CreerDepenseAsync(
        Membre auteur,
        string label,
        decimal montant,
        IReadOnlyList<Guid> participants,
        Guid? paidByMemberId = null)
    {
        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/events/{_evenement}/expenses", UriKind.Relative))
        {
            Content = JsonContent.Create(new
            {
                label,
                amount = montant,
                mode = "Selection",
                shares = participants.Select(id => new { memberId = id, share = 1 }).ToArray(),
                paidByMemberId,
            }),
        };

        // Les écritures financières exigent une clé d'idempotence (§8.1).
        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        var reponse = await auteur.Client.SendAsync(requete);

        reponse.EnsureSuccessStatusCode();
    }

    private Task<List<Notification>> NotificationsAsync() =>
        fixture.NotificationsAsync(_evenement.ToString());

    private sealed record Membre(Guid MemberId, Guid UserId, HttpClient Client);
}
