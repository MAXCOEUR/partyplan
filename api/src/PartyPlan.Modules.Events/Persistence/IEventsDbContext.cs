namespace PartyPlan.Modules.Events.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;

public interface IEventsDbContext
{
    DbSet<Event> Events { get; }

    DbSet<EventMember> EventMembers { get; }

    DbSet<EventScheduleItem> EventScheduleItems { get; }

    DbSet<ActivityEntry> ActivityEntries { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
