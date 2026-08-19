namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Lectures d'événements exposées par le module.</summary>
public sealed class EventReader(IEventsDbContext db)
{
    public static readonly DomainError NotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    /// <summary>
    /// Renvoie la synthèse d'un événement, ou <see cref="NotFound"/>.
    /// <para>
    /// Aucun contrôle d'appartenance n'apparaît ici : le filtre global du DbContext
    /// l'applique déjà (RG-SEC-01, RG-SEC-02). Un événement hors périmètre est donc
    /// invisible, et la réponse est un 404 — jamais un 403, qui confirmerait son
    /// existence. Cela vaut aussi pour un rôle plateforme (RG-ADM-01).
    /// </para>
    /// </summary>
    public async Task<Result<EventSummary>> GetSummaryAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var summary = await db.Events
            .Where(e => e.Id == eventId)
            .Select(e => new EventSummary(
                e.Id,
                e.Name,
                e.Description,
                e.StartsAt,
                e.EndsAt,
                e.Address,
                e.CoverImageUrl,
                e.Members.Count(m => m.RemovedAt == null),
                e.Members.Count(m => m.RemovedAt == null
                    && (m.Status == EventMemberStatus.Going
                        || m.Status == EventMemberStatus.Late
                        || m.Status == EventMemberStatus.EarlyLeave)),
                e.Members.Count(m => m.RemovedAt == null && m.Status == EventMemberStatus.Maybe),
                e.JoinEnabled))
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        return summary is null ? NotFound : summary;
    }
}
