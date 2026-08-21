namespace PartyPlan.Modules.Users.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Contracts;

public sealed class UserIdentityLookup(IUsersDbContext db) : IUserIdentityLookup
{
    public Task<UserIdentity?> FindAsync(Guid userId, CancellationToken cancellationToken) =>
        db.Users
            .AsNoTracking()
            .Where(u => u.Id == userId && u.DeletedAt == null)
            .Select(u => new UserIdentity(u.Id, u.DisplayName))
            .FirstOrDefaultAsync(cancellationToken);
}
