namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Décomptes d'événements pour les indicateurs d'instance (EF-ADM-10).
/// <para>
/// Le cloisonnement est volontairement ignoré : ce sont des agrégats sur l'ensemble de
/// l'instance, et non des lectures d'événements. Aucun contenu ne franchit ce contrat,
/// seulement des nombres — RG-ADM-01 reste donc respectée.
/// </para>
/// </summary>
public sealed class EventStatistics(IEventsDbContext db, IClock clock) : IEventStatistics
{
    public async Task<EventCounts> CountAsync(CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var total = await db.Events
            .IgnoreQueryFilters()
            .CountAsync(e => e.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        // « Actif » se juge sur la fin effective : un événement sans date de fin se
        // termine douze heures après son début (EF-EVT-02).
        var actifs = await db.Events
            .IgnoreQueryFilters()
            .CountAsync(
                e => e.DeletedAt == null
                     && e.ArchivedAt == null
                     && (e.EndsAt ?? e.StartsAt.AddHours(12)) > maintenant,
                cancellationToken)
            .ConfigureAwait(false);

        var invites = await db.EventMembers
            .IgnoreQueryFilters()
            .CountAsync(m => m.UserId == null && m.RemovedAt == null, cancellationToken)
            .ConfigureAwait(false);

        return new EventCounts(total, actifs, invites);
    }
}
