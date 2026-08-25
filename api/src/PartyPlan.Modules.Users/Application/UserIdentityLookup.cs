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
            .Select(u => new UserIdentity(u.Id, u.DisplayName, u.AvatarUrl))
            .FirstOrDefaultAsync(cancellationToken);

    public async Task<IReadOnlyDictionary<Guid, UserIdentity>> FindManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(userIds);

        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, UserIdentity>();
        }

        var identites = await db.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id) && u.DeletedAt == null)
            .Select(u => new UserIdentity(u.Id, u.DisplayName, u.AvatarUrl))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return identites.ToDictionary(i => i.Id);
    }
}
