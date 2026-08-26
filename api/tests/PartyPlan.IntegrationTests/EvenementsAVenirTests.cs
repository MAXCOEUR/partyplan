namespace PartyPlan.IntegrationTests;

using Microsoft.Extensions.DependencyInjection;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Fenêtre de l'ordonnanceur (`IEvenementsAVenir`).
/// <para>
/// La lecture lève le filtre de cloisonnement, faute de périmètre amorcé hors requête
/// HTTP. Ces tests vérifient qu'elle ne rend malgré tout que des dates et un
/// propriétaire, et qu'elle borne correctement — un horizon trop large ferait planifier
/// des rappels pour des soirées de l'an prochain à chaque minute.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class EvenementsAVenirTests(PartyPlanApiFixture fixture)
{
    private static readonly DateTimeOffset Maintenant =
        new(2026, 9, 12, 18, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Un_evenement_dans_l_horizon_est_rendu()
    {
        var eventId = await CreerAsync(Maintenant.AddDays(2));

        var liste = await ListerAsync(horizon: TimeSpan.FromDays(4));

        liste.ShouldContain(e => e.EventId == eventId);
    }

    [Fact]
    public async Task Un_evenement_au_dela_de_l_horizon_est_ecarte()
    {
        var eventId = await CreerAsync(Maintenant.AddDays(30));

        var liste = await ListerAsync(horizon: TimeSpan.FromDays(4));

        liste.ShouldNotContain(e => e.EventId == eventId);
    }

    [Fact]
    public async Task Un_evenement_termine_hier_reste_rendu()
    {
        // EF-NOT-06 notifie le lendemain de la fin : une fenêtre qui ne regarderait que
        // devant ne verrait jamais l'événement au moment où il faut relancer les dettes.
        var eventId = await CreerAsync(
            Maintenant.AddDays(-1).AddHours(-6),
            fin: Maintenant.AddDays(-1));

        var liste = await ListerAsync(retard: TimeSpan.FromDays(2));

        liste.ShouldContain(e => e.EventId == eventId);
    }

    [Fact]
    public async Task Un_evenement_termine_depuis_longtemps_est_ecarte()
    {
        var eventId = await CreerAsync(
            Maintenant.AddDays(-30),
            fin: Maintenant.AddDays(-29));

        var liste = await ListerAsync(retard: TimeSpan.FromDays(2));

        liste.ShouldNotContain(e => e.EventId == eventId);
    }

    [Fact]
    public async Task Un_evenement_supprime_est_ecarte()
    {
        var eventId = await CreerAsync(Maintenant.AddDays(2), supprime: true);

        (await ListerAsync()).ShouldNotContain(e => e.EventId == eventId);
    }

    [Fact]
    public async Task La_fin_effective_vaut_douze_heures_sans_fin_declaree()
    {
        // Même convention que le reste du domaine : Event.ImplicitDuration.
        var evenement = new EvenementAVenir(
            Guid.CreateVersion7(),
            Guid.CreateVersion7(),
            Maintenant,
            null);

        evenement.FinEffective.ShouldBe(Maintenant.AddHours(12));
    }

    private async Task<Guid> CreerAsync(
        DateTimeOffset debut,
        DateTimeOffset? fin = null,
        bool supprime = false)
    {
        var eventId = Guid.CreateVersion7();
        var userId = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new User
            {
                Id = userId,
                Email = $"avenir-{userId:N}@partyplan.test",
                DisplayName = "Alex",
                PasswordHash = "x",
                CreatedAt = DateTimeOffset.UtcNow,
            });

            db.Events.Add(new Event
            {
                Id = eventId,
                Name = "Soirée de fenêtre",
                StartsAt = debut,
                EndsAt = fin,
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = userId,
                DeletedAt = supprime ? DateTimeOffset.UtcNow : null,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = Guid.CreateVersion7(),
                EventId = eventId,
                UserId = userId,
                DisplayName = "Alex",
                Role = EventMemberRole.Owner,
                Status = EventMemberStatus.Going,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });

        return eventId;
    }

    private async Task<IReadOnlyList<EvenementAVenir>> ListerAsync(
        TimeSpan? horizon = null,
        TimeSpan? retard = null)
    {
        using var portee = fixture.Services.CreateScope();

        return await portee.ServiceProvider
            .GetRequiredService<IEvenementsAVenir>()
            .ListerAsync(
                Maintenant,
                horizon ?? TimeSpan.FromDays(4),
                retard ?? TimeSpan.FromDays(2),
                CancellationToken.None);
    }
}
