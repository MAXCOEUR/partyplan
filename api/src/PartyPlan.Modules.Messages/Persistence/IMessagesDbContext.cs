namespace PartyPlan.Modules.Messages.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Messages.Domain;

public interface IMessagesDbContext
{
    DbSet<Message> Messages { get; }

    DbSet<MessageReaction> MessageReactions { get; }

    DbSet<MessageMention> MessageMentions { get; }

    DbSet<PinFolder> PinFolders { get; }

    DbSet<PinnedMessage> PinnedMessages { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
