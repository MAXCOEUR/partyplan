namespace PartyPlan.Modules.Tasks.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Tasks.Domain;

public interface ITasksDbContext
{
    DbSet<EventTask> EventTasks { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
