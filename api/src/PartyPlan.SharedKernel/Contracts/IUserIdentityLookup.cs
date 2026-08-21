namespace PartyPlan.SharedKernel.Contracts;

public sealed record UserIdentity(Guid Id, string DisplayName);

public interface IUserIdentityLookup
{
    Task<UserIdentity?> FindAsync(Guid userId, CancellationToken cancellationToken);
}
