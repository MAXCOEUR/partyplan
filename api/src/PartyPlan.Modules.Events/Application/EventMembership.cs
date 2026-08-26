namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <inheritdoc />
public sealed class EventMembership(
    IEventsDbContext db,
    ICurrentUser currentUser,
    IUserIdentityLookup identites) : IEventMembership
{
    public async Task<IReadOnlyList<EventMemberRef>> ListActiveAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(db);

        var membres = await db.EventMembers
            .Where(m => m.EventId == eventId && m.RemovedAt == null)
            .OrderBy(m => m.JoinedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        // Une seule requête pour toutes les photos. Un appel par membre ferait vingt
        // requêtes pour vingt personnes, et le coût suivrait la taille de la soirée.
        var photos = await identites
            .FindManyAsync(
                [.. membres.Where(m => m.UserId is not null).Select(m => m.UserId!.Value)],
                cancellationToken)
            .ConfigureAwait(false);

        return
        [
            .. membres.Select(m => new EventMemberRef(
                m.Id,
                m.DisplayName,
                m.UserId is { } id && photos.TryGetValue(id, out var identite)
                    ? identite.AvatarUrl
                    : null,
                m.CountsAsPresent,
                m.CanManageEvent,
                m.UserId)),
        ];
    }

    public Task<bool> IsMemberAsync(
        Guid eventId,
        Guid userId,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(db);

        // IgnoreQueryFilters est indispensable, et pour la même raison que dans
        // EventScopePrimer : cette requête établit l'appartenance, elle ne peut donc pas
        // être soumise au filtre que l'appartenance alimente. Le cloisonnement est
        // assuré par la condition explicite sur le compte, pas par le filtre.
        return db.EventMembers
            .IgnoreQueryFilters()
            .AnyAsync(
                m => m.EventId == eventId
                    && m.UserId == userId
                    && m.RemovedAt == null,
                cancellationToken);
    }

    public async Task<EventMemberRef?> FindCurrentAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(currentUser);

        var membre = currentUser.UserId is { } userId
            ? await db.EventMembers
                .FirstOrDefaultAsync(
                    m => m.EventId == eventId && m.UserId == userId && m.RemovedAt == null,
                    cancellationToken)
                .ConfigureAwait(false)
            : null;

        if (membre is null)
        {
            return null;
        }

        var identite = membre.UserId is { } id
            ? await identites.FindAsync(id, cancellationToken).ConfigureAwait(false)
            : null;

        return new EventMemberRef(
            membre.Id,
            membre.DisplayName,
            identite?.AvatarUrl,
            membre.CountsAsPresent,
            membre.CanManageEvent,
            membre.UserId);
    }
}
