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

    /// <summary>
    /// Sondage porté par ce message.
    /// <para>
    /// Simple identifiant, sans clé étrangère : les sondages appartiennent à un autre
    /// module, et une relation posée ici franchirait la frontière (ADR 0002).
    /// </para>
    /// </summary>
    public Guid? PollId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? EditedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public ICollection<MessageReaction> Reactions { get; } = new List<MessageReaction>();

    public ICollection<MessageMention> Mentions { get; } = new List<MessageMention>();
}

/// <summary>
/// Personne nommée dans un message.
/// <para>
/// Enregistrée plutôt que relue dans le texte à chaque affichage : c'est ce qui
/// permettra de notifier la personne citée sans réanalyser tout l'historique, et un nom
/// changé entre-temps ne doit pas défaire la mention.
/// </para>
/// </summary>
public sealed class MessageMention
{
    public Guid Id { get; set; }

    public Guid MessageId { get; set; }

    /// <summary>Membre cité. Un invité sans compte se cite comme les autres.</summary>
    public Guid MemberId { get; set; }
}

/// <summary>
/// Dossier de rangement des messages épinglés.
/// <para>
/// Toujours partagé : la décision produit du 21/08/2026 écarte les épingles privées.
/// Un dossier sert à ce que le groupe retrouve le code du portail que quelqu'un
/// d'autre a donné.
/// </para>
/// </summary>
public sealed class PinFolder : IEventScoped
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public string Name { get; set; } = string.Empty;

    public Guid CreatedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>
/// Message épinglé, avec ou sans dossier.
/// <para>
/// <see cref="FolderId"/> nul signifie « épinglé sans rangement » : classer est un
/// travail, et l'imposer au moment où l'on veut simplement retenir une information
/// ferait renoncer à épingler.
/// </para>
/// </summary>
public sealed class PinnedMessage : IEventScoped
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public Guid MessageId { get; set; }

    public Guid? FolderId { get; set; }

    public Guid PinnedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class MessageReaction
{
    public Guid Id { get; set; }

    public Guid MessageId { get; set; }

    public Guid MemberId { get; set; }

    public string Emoji { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }
}

/// <summary>
/// Jusqu'où un membre a lu la discussion d'un événement.
/// <para>
/// Une ligne par membre et par événement : le repère est celui d'une personne, non d'un
/// appareil. Ouvrir la discussion sur son téléphone puis sur son ordinateur ne doit pas
/// faire réapparaître comme non lu ce qui vient d'être lu.
/// </para>
/// <para>
/// Le membre, jamais le compte : un invité sans compte lit la discussion comme les
/// autres (règle 7 du projet).
/// </para>
/// </summary>
public sealed class MessageRead : IEventScoped
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public Guid MemberId { get; set; }

    /// <summary>Dernier message lu. Ce repère n'est jamais reculé.</summary>
    public Guid LastReadMessageId { get; set; }

    /// <summary>
    /// Date du message repéré, recopiée ici.
    /// <para>
    /// Comparer des dates plutôt que remonter au message permet de compter les non-lus
    /// en une requête, et le compte survit à la suppression du message repéré.
    /// </para>
    /// </summary>
    public DateTimeOffset LastReadAt { get; set; }
}
