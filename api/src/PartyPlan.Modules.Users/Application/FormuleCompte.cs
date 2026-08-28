namespace PartyPlan.Modules.Users.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Lit la formule sur <c>users.premium_until</c>.
/// <para>
/// Un compte supprimé est traité comme absent : sa formule n'a plus d'objet, et le
/// laisser abonné permettrait à un compte anonymisé de lever encore un quota.
/// </para>
/// </summary>
public sealed class FormuleCompte(IUsersDbContext db, IClock clock) : IFormuleCompte
{
    public async Task<bool> EstAbonneAsync(Guid userId, CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        return await db.Users
            .AsNoTracking()
            .AnyAsync(
                u => u.Id == userId
                    && u.DeletedAt == null
                    && u.PremiumUntil != null
                    && u.PremiumUntil > maintenant,
                cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<IReadOnlyDictionary<Guid, bool>> EstAbonneManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(userIds);

        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, bool>();
        }

        var maintenant = clock.UtcNow;

        var comptes = await db.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id) && u.DeletedAt == null)
            .Select(u => new { u.Id, u.PremiumUntil })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return comptes.ToDictionary(
            c => c.Id,
            c => c.PremiumUntil != null && c.PremiumUntil > maintenant);
    }
}
