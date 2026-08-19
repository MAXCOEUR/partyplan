namespace PartyPlan.Modules.Polls.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Polls.Domain;

public interface IPollsDbContext
{
    DbSet<Poll> Polls { get; }

    DbSet<PollOption> PollOptions { get; }

    DbSet<PollVote> PollVotes { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
