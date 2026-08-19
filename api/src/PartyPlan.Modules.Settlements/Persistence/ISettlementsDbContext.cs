namespace PartyPlan.Modules.Settlements.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Settlements.Domain;

public interface ISettlementsDbContext
{
    DbSet<Settlement> Settlements { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
