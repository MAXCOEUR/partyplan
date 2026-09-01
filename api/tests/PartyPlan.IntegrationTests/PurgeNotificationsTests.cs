namespace PartyPlan.IntegrationTests;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Purge de l'historique des notifications.
/// <para>
/// La table est en écriture permanente : chaque rappel, chaque message, chaque dépense y
/// laisse une ligne par destinataire. Sans purge, elle est la seule table du produit dont
/// la taille croît sans jamais décroître, pour un contenu que personne ne relit.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class PurgeNotificationsTests(PartyPlanApiFixture fixture)
{
    /// <summary>
    /// Instant de référence, volontairement postérieur à celui des autres suites.
    /// <para>
    /// L'ordonnanceur est un singleton : il retient la date de sa dernière purge, et une
    /// suite qui passerait après à une date antérieure fausserait le rythme observé ici.
    /// </para>
    /// </summary>
    private static readonly DateTimeOffset Maintenant =
        new(2027, 3, 1, 16, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Une_notification_plus_vieille_que_la_retention_est_supprimee()
    {
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, "vieille", Maintenant.AddDays(-31));

        await PurgerAsync(Maintenant);

        (await LireAsync(jeu.EventId)).ShouldBeEmpty();
    }

    [Fact]
    public async Task Une_notification_dans_la_retention_est_conservee()
    {
        // La borne compte : le centre de notifications doit garder un mois d'historique,
        // et une purge trop large ferait disparaître ce qu'on vient de recevoir.
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, "recente", Maintenant.AddDays(-29));

        await PurgerAsync(Maintenant);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem();
    }

    [Fact]
    public async Task Une_notification_non_encore_envoyee_est_conservee()
    {
        // Un rappel planifié loin devant, mais inscrit il y a longtemps, n'est pas de
        // l'historique : le supprimer priverait la soirée de son rappel.
        var jeu = await JeuAsync();
        await EnfilerAsync(
            jeu,
            "planifiee",
            Maintenant.AddDays(-31),
            prevuePour: Maintenant.AddDays(2));

        await PurgerAsync(Maintenant);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem();
    }

    [Fact]
    public async Task Une_passe_de_l_ordonnanceur_purge_l_historique()
    {
        // Sans ce branchement, la purge existe mais n'est jamais appelée. Elle est placée
        // avant la planification : une passe qui ne trouve aucune soirée à venir s'arrête
        // tôt, et l'historique ne serait purgé que les semaines où quelqu'un organise
        // quelque chose.
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, "vieille", Maintenant.AddDays(-31));

        await PasserAsync(Maintenant);

        (await LireAsync(jeu.EventId)).ShouldBeEmpty();
    }

    [Fact]
    public async Task La_purge_ne_se_repete_pas_a_chaque_minute()
    {
        // L'ordonnanceur se réveille toutes les minutes. Purger à chaque passe ferait
        // 1 440 suppressions par jour pour retirer, au mieux, les lignes d'une journée.
        var jeu = await JeuAsync();
        await PasserAsync(Maintenant);

        await EnfilerAsync(jeu, "vieille", Maintenant.AddDays(-31));
        await PasserAsync(Maintenant.AddMinutes(1));

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem();

        await PasserAsync(Maintenant.AddHours(25));

        (await LireAsync(jeu.EventId)).ShouldBeEmpty();
    }

    /// <summary>Exécute une passe complète de l'ordonnanceur à un instant donné.</summary>
    private Task PasserAsync(DateTimeOffset instant) =>
        fixture.Services
            .GetRequiredService<OrdonnanceurNotifications>()
            .PasseAsync(instant, CancellationToken.None);

    private async Task<int> PurgerAsync(DateTimeOffset instant)
    {
        using var portee = fixture.Services.CreateScope();

        return await portee.ServiceProvider
            .GetRequiredService<IPurgeNotifications>()
            .PurgerAsync(instant, CancellationToken.None);
    }

    private async Task EnfilerAsync(
        Jeu jeu,
        string categorie,
        DateTimeOffset creeeLe,
        DateTimeOffset? prevuePour = null)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.Notifications.Add(new Notification
            {
                Id = Guid.CreateVersion7(),
                UserId = jeu.Compte,
                EventId = jeu.EventId,
                Category = categorie,
                Title = "Titre",
                Body = "Corps",
                DeepLink = $"/events/{jeu.EventId}",
                ScheduledFor = prevuePour ?? creeeLe,
                SentAt = prevuePour is null ? creeeLe : null,
                CreatedAt = creeeLe,
                DedupKey = $"{jeu.EventId}:{categorie}:{jeu.Compte}:{Guid.NewGuid():N}",
            });

            await db.SaveChangesAsync();
        });
    }

    private async Task<List<Notification>> LireAsync(Guid eventId)
    {
        List<Notification> lignes = [];

        await fixture.WithDatabaseAsync(async db =>
            lignes = await db.Notifications
                .Where(n => n.EventId == eventId)
                .ToListAsync());

        return lignes;
    }

    private async Task<Jeu> JeuAsync()
    {
        var compte = Guid.CreateVersion7();
        var eventId = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new User
            {
                Id = compte,
                Email = $"purge-{compte:N}@partyplan.test",
                DisplayName = "Camille",
                PasswordHash = "x",
                Timezone = "Europe/Paris",
                CreatedAt = DateTimeOffset.UtcNow,
            });

            db.Events.Add(new Event
            {
                Id = eventId,
                Name = "Soirée de purge",
                StartsAt = Maintenant.AddDays(3),
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = compte,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = Guid.CreateVersion7(),
                EventId = eventId,
                UserId = compte,
                DisplayName = "Camille",
                Role = EventMemberRole.Owner,
                Status = EventMemberStatus.Going,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });

        return new Jeu(compte, eventId);
    }

    private sealed record Jeu(Guid Compte, Guid EventId);
}
