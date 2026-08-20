namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <inheritdoc />
public sealed class EventMembership(IEventsDbContext db, ICurrentUser currentUser)
    : IEventMembership
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

        return
        [
            .. membres.Select(m => new EventMemberRef(
                m.Id,
                m.DisplayName,
                m.CountsAsPresent,
                m.CanManageEvent)),
        ];
    }

    public async Task<EventMemberRef?> FindCurrentAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(db);
        ArgumentNullException.ThrowIfNull(currentUser);

        // Un invité sans compte est identifié par la ligne que porte son jeton, jamais
        // par « le premier membre sans compte » : deux invités les confondraient.
        var membre = currentUser.UserId is { } userId
            ? await db.EventMembers
                .FirstOrDefaultAsync(
                    m => m.EventId == eventId && m.UserId == userId && m.RemovedAt == null,
                    cancellationToken)
                .ConfigureAwait(false)
            : currentUser.GuestMemberId is { } membreInvite
                ? await db.EventMembers
                    .FirstOrDefaultAsync(
                        m => m.EventId == eventId
                          && m.Id == membreInvite
                          && m.RemovedAt == null,
                        cancellationToken)
                    .ConfigureAwait(false)
                : null;

        return membre is null
            ? null
            : new EventMemberRef(
                membre.Id,
                membre.DisplayName,
                membre.CountsAsPresent,
                membre.CanManageEvent);
    }
}
