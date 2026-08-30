namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Déclencheur des sondages (tâche 5 du lot notifications) : un sondage créé prévient
/// tous les membres de la soirée, sauf son auteur et les membres sans compte.
/// <para>
/// La soirée compte trois membres : <see cref="_auteur"/> qui lance le sondage,
/// <see cref="_lucas"/> qui reçoit, et un invité sans compte — présent uniquement pour
/// vérifier qu'il n'est jamais notifié (RG-INV-04).
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class NotificationsSondagesTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    private Guid _evenement;
    private Membre _auteur = null!;
    private Membre _lucas = null!;

    public async Task InitializeAsync()
    {
        var (hote, _) = await fixture.CompteAvecJetonAsync("Camille");
        var (eventId, jetonInvitation) = await hote.CreerEvenementAsync("Soirée du sondage");
        _evenement = Guid.Parse(eventId);

        var lucas = await fixture.CompteAsync("Lucas");
        await lucas.RejoindreAsync(jetonInvitation);

        // Le créateur d'un événement porte toujours « Organisateur » comme nom de membre,
        // distinct du nom de son compte (EventService.CreerAsync).
        _auteur = await MembreAsync("Organisateur", hote);
        _lucas = await MembreAsync("Lucas", lucas);

        // Un invité historique, sans compte : jamais notifié, quel que soit le sondage
        // (RG-INV-04, §7 de CLAUDE.md).
        await fixture.WithDatabaseAsync(async db =>
        {
            db.EventMembers.Add(new EventMember
            {
                Id = Guid.CreateVersion7(),
                EventId = _evenement,
                UserId = null,
                DisplayName = "Invité sans compte",
                Status = EventMemberStatus.Unknown,
                Role = EventMemberRole.Member,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Un_sondage_notifie_tous_les_membres_sauf_son_auteur()
    {
        await CreerSondageAsync(_auteur, "On prend quoi en dessert ?", ["Tarte", "Glaces"]);

        var notifs = await NotificationsAsync();

        notifs.ShouldNotContain(n => n.UserId == _auteur.UserId);
        notifs.ShouldContain(n => n.UserId == _lucas.UserId
            && n.Category == NotificationCategories.PollNew);
    }

    [Fact]
    public async Task Un_membre_sans_compte_n_est_jamais_notifie()
    {
        await CreerSondageAsync(_auteur, "On prend quoi en dessert ?", ["Tarte", "Glaces"]);

        var notifs = await NotificationsAsync();

        notifs.ShouldNotContain(n => n.UserId == null);
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

    private async Task CreerSondageAsync(Membre auteur, string question, IReadOnlyList<string> options)
    {
        var reponse = await auteur.Client.PostAsJsonAsync(
            $"/v1/events/{_evenement}/polls",
            new { question, options, allowMultiple = false });

        reponse.EnsureSuccessStatusCode();
    }

    private Task<List<Notification>> NotificationsAsync() =>
        fixture.NotificationsAsync(_evenement.ToString());

    private sealed record Membre(Guid MemberId, Guid UserId, HttpClient Client);
}
