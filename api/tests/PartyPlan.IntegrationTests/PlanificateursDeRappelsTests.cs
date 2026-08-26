namespace PartyPlan.IntegrationTests;

using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Shopping.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Rappels temporels (EF-NOT-03 à EF-NOT-06), éprouvés à travers l'ordonnanceur.
/// <para>
/// L'idempotence y est le test qui compte : l'ordonnanceur balaie toutes les minutes, et
/// un rappel qui repartirait à chaque passe saturerait les téléphones. On ne s'en
/// apercevrait pas en développement, où l'on ne laisse jamais tourner une heure.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class PlanificateursDeRappelsTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task EF_NOT_03_les_sans_reponse_sont_relances_a_J_3()
    {
        var soiree = await SoireeAsync(debutDansJours: 3);

        await PasserAsync(soiree.Maintenant);

        var avis = await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.InvitationPending);

        avis.ShouldContain(n => n.UserId == soiree.CompteCamille);
        avis.ShouldAllBe(n => n.DedupKey.EndsWith("j-3", StringComparison.Ordinal));
    }

    [Fact]
    public async Task EF_NOT_03_celui_qui_a_repondu_n_est_pas_relance()
    {
        var soiree = await SoireeAsync(debutDansJours: 3, statutCamille: EventMemberStatus.Going);

        await PasserAsync(soiree.Maintenant);

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.InvitationPending))
            .ShouldNotContain(n => n.UserId == soiree.CompteCamille);
    }

    [Fact]
    public async Task Trois_passes_consecutives_ne_produisent_qu_un_rappel()
    {
        // Le test qui compte. Sans la clé de déduplication, ce serait trois.
        var soiree = await SoireeAsync(debutDansJours: 3);

        await PasserAsync(soiree.Maintenant);
        await PasserAsync(soiree.Maintenant.AddMinutes(1));
        await PasserAsync(soiree.Maintenant.AddMinutes(2));

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.InvitationPending))
            .Count(n => n.UserId == soiree.CompteCamille)
            .ShouldBe(1);
    }

    [Fact]
    public async Task EF_NOT_05_le_rappel_de_debut_part_deux_heures_avant()
    {
        var soiree = await SoireeAsync(
            debutDansHeures: 2,
            statutCamille: EventMemberStatus.Going);

        await PasserAsync(soiree.Maintenant);

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.EventStartingSoon))
            .ShouldContain(n => n.UserId == soiree.CompteCamille);
    }

    [Fact]
    public async Task EF_NOT_05_un_absent_n_est_pas_rappele()
    {
        var soiree = await SoireeAsync(
            debutDansHeures: 2,
            statutCamille: EventMemberStatus.NotGoing);

        await PasserAsync(soiree.Maintenant);

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.EventStartingSoon))
            .ShouldNotContain(n => n.UserId == soiree.CompteCamille);
    }

    [Fact]
    public async Task EF_NOT_05_trois_heures_avant_c_est_trop_tot()
    {
        var soiree = await SoireeAsync(
            debutDansHeures: 3,
            statutCamille: EventMemberStatus.Going);

        await PasserAsync(soiree.Maintenant);

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.EventStartingSoon)).ShouldBeEmpty();
    }

    [Fact]
    public async Task EF_NOT_04_l_organisateur_est_prevenu_des_articles_sans_preneur()
    {
        var soiree = await SoireeAsync(debutDansHeures: 20);
        await AjouterArticleAsync(soiree.EventId, attribue: false);

        await PasserAsync(soiree.Maintenant);

        var avis = (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.ShoppingUnclaimed)).ShouldHaveSingleItem();

        avis.UserId.ShouldBe(soiree.CompteAlex);
    }

    [Fact]
    public async Task EF_NOT_04_une_liste_entierement_attribuee_ne_produit_rien()
    {
        var soiree = await SoireeAsync(debutDansHeures: 20);
        await AjouterArticleAsync(soiree.EventId, attribue: true, membreId: soiree.MembreAlex);

        await PasserAsync(soiree.Maintenant);

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.ShoppingUnclaimed)).ShouldBeEmpty();
    }

    [Fact]
    public async Task EF_NOT_04_une_liste_vide_ne_produit_rien()
    {
        // Annoncer « 0 article sans preneur » serait une notification pour dire qu'il ne
        // se passe rien.
        var soiree = await SoireeAsync(debutDansHeures: 20);

        await PasserAsync(soiree.Maintenant);

        (await fixture.NotificationsAsync(
            soiree.EventId, NotificationCategories.ShoppingUnclaimed)).ShouldBeEmpty();
    }

    /// <summary>Exécute une passe de l'ordonnanceur à un instant donné.</summary>
    private Task PasserAsync(DateTimeOffset instant) =>
        fixture.Services
            .GetRequiredService<OrdonnanceurNotifications>()
            .PasseAsync(instant, CancellationToken.None);

    private async Task AjouterArticleAsync(
        string eventId,
        bool attribue,
        Guid? membreId = null)
    {
        var id = Guid.Parse(eventId);

        await fixture.WithDatabaseAsync(async db =>
        {
            db.ShoppingItems.Add(new ShoppingItem
            {
                Id = Guid.CreateVersion7(),
                EventId = id,
                Name = "Glaçons",
                Quantity = 1m,
                Position = 0,
                AssignedMemberId = attribue ? membreId : null,
                AssignedAt = attribue ? DateTimeOffset.UtcNow : null,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    private async Task<Soiree> SoireeAsync(
        int debutDansJours = 0,
        int debutDansHeures = 0,
        EventMemberStatus statutCamille = EventMemberStatus.Unknown)
    {
        var maintenant = new DateTimeOffset(2026, 9, 12, 14, 0, 0, TimeSpan.Zero);
        var debut = maintenant.AddDays(debutDansJours).AddHours(debutDansHeures);

        var eventId = Guid.CreateVersion7();
        var alex = Guid.CreateVersion7();
        var camille = Guid.CreateVersion7();
        var membreAlex = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.AddRange(
                Compte(alex, "Alex"),
                Compte(camille, "Camille"));

            db.Events.Add(new Event
            {
                Id = eventId,
                Name = "Soirée des rappels",
                StartsAt = debut,
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = alex,
            });

            db.EventMembers.AddRange(
                new EventMember
                {
                    Id = membreAlex,
                    EventId = eventId,
                    UserId = alex,
                    DisplayName = "Alex",
                    Role = EventMemberRole.Owner,
                    Status = EventMemberStatus.Going,
                    JoinedAt = maintenant,
                },
                new EventMember
                {
                    Id = Guid.CreateVersion7(),
                    EventId = eventId,
                    UserId = camille,
                    DisplayName = "Camille",
                    Role = EventMemberRole.Member,
                    Status = statutCamille,
                    JoinedAt = maintenant,
                });

            await db.SaveChangesAsync();
        });

        return new Soiree(eventId.ToString(), alex, camille, membreAlex, maintenant);
    }

    private static User Compte(Guid id, string nom) => new()
    {
        Id = id,
        Email = $"rappel-{id:N}@partyplan.test",
        DisplayName = nom,
        PasswordHash = "x",
        CreatedAt = DateTimeOffset.UtcNow,
    };

    private sealed record Soiree(
        string EventId,
        Guid CompteAlex,
        Guid CompteCamille,
        Guid MembreAlex,
        DateTimeOffset Maintenant);
}
