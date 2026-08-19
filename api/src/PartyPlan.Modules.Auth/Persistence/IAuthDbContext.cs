namespace PartyPlan.Modules.Auth.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Auth.Domain;

public interface IAuthDbContext
{
    DbSet<PasswordResetToken> PasswordResetTokens { get; }

    DbSet<EmailVerificationToken> EmailVerificationTokens { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
