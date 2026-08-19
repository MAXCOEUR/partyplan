namespace PartyPlan.Modules.Messages.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Messages.Domain;

public interface IMessagesDbContext
{
    DbSet<Message> Messages { get; }

    DbSet<MessageReaction> MessageReactions { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
