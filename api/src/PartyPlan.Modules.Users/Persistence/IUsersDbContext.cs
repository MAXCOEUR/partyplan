namespace PartyPlan.Modules.Users.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Domain;

/// <summary>
/// Accès aux seules tables du module Users. C'est ce contrat, et non une convention
/// orale, qui matérialise la frontière de l'ADR 0002 : un module ne peut pas requêter
/// une table qu'il ne déclare pas.
/// </summary>
public interface IUsersDbContext
{
    DbSet<User> Users { get; }

    DbSet<Session> Sessions { get; }

    DbSet<Group> Groups { get; }

    DbSet<GroupMember> GroupMembers { get; }

    DbSet<PasswordResetToken> PasswordResetTokens { get; }

    DbSet<EmailVerificationToken> EmailVerificationTokens { get; }


    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
