namespace PartyPlan.Modules.Messages.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Message de la discussion d'un événement (EF-MSG-01). Fonctionnalité secondaire :
/// aucune ambition de messagerie généraliste (RG-MSG-01).
/// </summary>
public sealed class Message : IEventScoped, ISoftDeletable
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public Guid MemberId { get; set; }

    public string? Body { get; set; }

    public string? AttachmentUrl { get; set; }

    /// <summary>Message auquel celui-ci répond (EF-MSG-04).</summary>
    public Guid? ReplyToMessageId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? EditedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public ICollection<MessageReaction> Reactions { get; } = new List<MessageReaction>();
}

public sealed class MessageReaction
{
    public Guid Id { get; set; }

    public Guid MessageId { get; set; }

    public Guid MemberId { get; set; }

    public string Emoji { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }
}
