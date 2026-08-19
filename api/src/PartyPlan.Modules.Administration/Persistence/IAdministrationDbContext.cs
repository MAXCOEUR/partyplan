namespace PartyPlan.Modules.Administration.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Administration.Domain;

public interface IAdministrationDbContext
{
    DbSet<AdminAuditEntry> AdminAuditEntries { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
