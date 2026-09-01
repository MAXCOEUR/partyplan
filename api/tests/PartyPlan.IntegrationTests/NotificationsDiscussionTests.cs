namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Déclencheur des messages (tâche 4 du lot notifications) : un message posté prévient
/// les autres membres, une citation nommée prévient à part.
/// <para>
/// La soirée compte trois membres : <see cref="_auteur"/> qui écrit, <see cref="_lucas"/>
/// qui reçoit, et un invité sans compte — présent uniquement pour vérifier qu'il n'est
/// jamais notifié (RG-INV-04).
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class NotificationsDiscussionTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    /// <summary>18 h à Paris.</summary>
    private static readonly DateTimeOffset SoireeAParis = new(2026, 9, 12, 16, 0, 0, TimeSpan.Zero);

    private Guid _evenement;
    private Membre _auteur = null!;
    private Membre _lucas = null!;

    public async Task InitializeAsync()
    {
        var (hote, _) = await fixture.CompteAvecJetonAsync("Camille");
        var (eventId, jetonInvitation) = await hote.CreerEvenementAsync("Soirée de la discussion");
        _evenement = Guid.Parse(eventId);

        var lucas = await fixture.CompteAsync("Lucas");
        await lucas.RejoindreAsync(jetonInvitation);

        // Le créateur d'un événement porte toujours « Organisateur » comme nom de membre,
        // distinct du nom de son compte (EventService.CreerAsync).
        _auteur = await MembreAsync("Organisateur", hote);
        _lucas = await MembreAsync("Lucas", lucas);

        // Un invité historique, sans compte : jamais notifié, quel que soit le message
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
    public async Task Une_notification_de_message_ouvre_l_onglet_discussion()
    {
        // Ouvrir la soirée sur son tableau de bord laisse chercher la conversation qu'on
        // vient d'être averti de recevoir.
        await EnvoyerMessageAsync(_auteur, "On se retrouve à 20h.");

        var notifs = await NotificationsAsync();

        notifs.ShouldAllBe(n => n.DeepLink == $"/events/{_evenement}/discussion");
    }

    [Fact]
    public async Task Un_message_notifie_les_autres_membres_jamais_son_auteur()
    {
        await EnvoyerMessageAsync(_auteur, "On se retrouve à 20h.");

        var notifs = await NotificationsAsync();

        notifs.ShouldNotContain(n => n.UserId == _auteur.UserId);
        notifs.ShouldContain(n => n.UserId == _lucas.UserId
            && n.Category == NotificationCategories.DiscussionMessage);
    }

    [Fact]
    public async Task Une_personne_citee_recoit_sa_mention_meme_si_le_bavardage_est_coupe()
    {
        // C'est le sens du découpage en deux catégories : couper le bavardage ne coupe pas
        // le fait d'être appelé nommément.
        await PoserPreferenceGlobaleAsync(_lucas.UserId, NotificationCategories.DiscussionMessage, actif: false);

        await EnvoyerMessageAsync(_auteur, "@Lucas tu ramènes la glace ?", cite: [_lucas.MemberId]);

        var partis = await EnvoyerLesDuesAsync();

        partis.ShouldBe(1);
    }

    [Fact]
    public async Task Une_personne_citee_ne_recoit_pas_aussi_le_message_simple()
    {
        await EnvoyerMessageAsync(_auteur, "@Lucas tu ramènes la glace ?", cite: [_lucas.MemberId]);

        var notifs = await NotificationsAsync();

        notifs.Where(n => n.UserId == _lucas.UserId).ShouldHaveSingleItem();
        notifs.Single(n => n.UserId == _lucas.UserId).Category.ShouldBe(NotificationCategories.DiscussionMention);
    }

    [Fact]
    public async Task Un_membre_sans_compte_n_est_jamais_notifie()
    {
        await EnvoyerMessageAsync(_auteur, "Salut.");

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

    private async Task EnvoyerMessageAsync(Membre auteur, string texte, IReadOnlyList<Guid>? cite = null)
    {
        var reponse = await auteur.Client.PostAsJsonAsync(
            $"/v1/events/{_evenement}/messages",
            new { body = texte, mentionedMemberIds = cite });

        reponse.EnsureSuccessStatusCode();
    }

    private Task<List<Notification>> NotificationsAsync() =>
        fixture.NotificationsAsync(_evenement.ToString());

    /// <summary>
    /// Déclenche la passe d'envoi et rend le nombre de notifications de <b>cette</b>
    /// soirée qui viennent de partir.
    /// <para>
    /// La passe elle-même est globale : la collection de tests partage une base entre
    /// classes, et une notification laissée en file par une autre suite fausserait un
    /// compte pris sur la valeur qu'elle renvoie. La différence avant/après, prise sur
    /// les seules lignes de <see cref="_evenement"/>, isole le résultat de ce que fait le
    /// reste de la collection.
    /// </para>
    /// </summary>
    private async Task<int> EnvoyerLesDuesAsync()
    {
        var avant = (await NotificationsAsync()).Count(n => n.SentAt is not null);

        using var portee = fixture.Services.CreateScope();
        await portee.ServiceProvider
            .GetRequiredService<IEnvoiNotifications>()
            .EnvoyerLesDuesAsync(SoireeAParis, CancellationToken.None)
            .ConfigureAwait(false);

        var apres = (await NotificationsAsync()).Count(n => n.SentAt is not null);

        return apres - avant;
    }

    private async Task PoserPreferenceGlobaleAsync(Guid utilisateur, string categorie, bool actif)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.NotificationPreferences.Add(new NotificationPreference
            {
                Id = Guid.CreateVersion7(),
                UserId = utilisateur,
                Category = categorie,
                PushEnabled = actif,
                EmailEnabled = actif,
                UpdatedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    private sealed record Membre(Guid MemberId, Guid UserId, HttpClient Client);
}
