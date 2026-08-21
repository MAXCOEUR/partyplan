namespace PartyPlan.Modules.Messages.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Messages.Domain;
using PartyPlan.Modules.Messages.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Réaction agrégée : un emoji, son décompte, et si l'appelant l'a posée.</summary>
public sealed record ReactionView(string Emoji, int Count, bool Mine);

/// <summary>Personne citée dans un message.</summary>
public sealed record MentionView(Guid MemberId, string DisplayName);

/// <summary>
/// Message cité par une réponse, réduit à ce qu'il faut pour s'y retrouver.
/// <para>
/// Le corps est tronqué : afficher un message de quatre mille caractères au-dessus
/// d'une réponse de trois mots noierait la réponse.
/// </para>
/// </summary>
public sealed record ReplyView(Guid Id, string AuthorDisplayName, string? Body);

/// <summary>Message du fil, tel que l'interface l'affiche.</summary>
public sealed record MessageView(
    Guid Id,
    Guid AuthorMemberId,
    string AuthorDisplayName,
    string? Body,
    string? AttachmentUrl,
    Guid? PollId,
    ReplyView? ReplyTo,
    IReadOnlyList<ReactionView> Reactions,
    IReadOnlyList<MentionView> Mentions,
    bool Mine,
    bool Edited,
    bool Deleted,
    bool Pinned,
    DateTimeOffset CreatedAt);

/// <summary>Fil de discussion.</summary>
public sealed record MessagePage(IReadOnlyList<MessageView> Items);

/// <summary>Envoi ou modification d'un message.</summary>
public sealed record MessageRequest(
    string? Body,
    string? AttachmentUrl,
    Guid? ReplyToMessageId,
    Guid? PollId,
    IReadOnlyList<Guid>? MentionedMemberIds);

/// <summary>Dossier d'épingles.</summary>
public sealed record PinFolderView(Guid Id, string Name, int Count);

/// <summary>Message épinglé, avec son rangement.</summary>
public sealed record PinView(
    Guid Id,
    Guid? FolderId,
    string? FolderName,
    MessageView Message,
    DateTimeOffset CreatedAt);

/// <summary>Épingles et dossiers d'un événement.</summary>
public sealed record PinPage(
    IReadOnlyList<PinFolderView> Folders,
    IReadOnlyList<PinView> Items);

/// <summary>
/// Discussion d'un événement (EF-MSG-01 à EF-MSG-06).
/// <para>
/// Fonctionnalité secondaire, sans ambition de messagerie généraliste (RG-MSG-01) :
/// pas de fil par sujet, pas de messages privés, pas d'accusés de lecture. Ce qu'on
/// attend d'elle, c'est de se mettre d'accord sur la musique et de retrouver le code du
/// portail.
/// </para>
/// <para>
/// L'auteur d'un message est sa ligne de membre, jamais un compte : un invité sans
/// compte écrit, réagit et épingle comme les autres (EF-INV-04).
/// </para>
/// </summary>
public sealed class MessageService(
    IMessagesDbContext db,
    IEventMembership membership,
    IClock clock,
    IIdGenerator ids)
{
    /// <summary>Longueur du corps d'un message cité, au-delà de laquelle il est coupé.</summary>
    private const int LongueurCitation = 120;

    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NotFound = DomainError.NotFound(
        "message.not_found",
        "Ce message est introuvable.");

    public static readonly DomainError Empty = DomainError.Validation(
        "message.empty",
        "Écris quelque chose, ou joins une image.");

    public static readonly DomainError NotMine = DomainError.Rule(
        "message.not_mine",
        "On ne modifie que ses propres messages.");

    public static readonly DomainError UnknownMention = DomainError.Validation(
        "message.unknown_mention",
        "Une des personnes citées n'est pas membre de cet événement.");

    public static readonly DomainError UnknownReply = DomainError.Validation(
        "message.unknown_reply",
        "Le message auquel tu réponds est introuvable.");

    public static readonly DomainError EmojiRequired = DomainError.Validation(
        "message.emoji_required",
        "Choisis une réaction.");

    public static readonly DomainError FolderNameRequired = DomainError.Validation(
        "pin.folder_name_required",
        "Donne un nom au dossier.");

    public static readonly DomainError FolderExists = DomainError.Conflict(
        "pin.folder_exists",
        "Un dossier porte déjà ce nom.");

    public static readonly DomainError FolderNotFound = DomainError.NotFound(
        "pin.folder_not_found",
        "Ce dossier est introuvable.");

    public static readonly DomainError NotPinned = DomainError.NotFound(
        "pin.not_found",
        "Ce message n'est pas épinglé.");

    // --------------------------------------------------------------------- fil ----

    public async Task<Result<MessagePage>> ListerAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var noms = await NomsAsync(eventId, cancellationToken).ConfigureAwait(false);

        // Ordre chronologique : une conversation se lit dans l'ordre où elle s'est
        // tenue, sans quoi une réponse précède la question qu'elle traite.
        var messages = await db.Messages
            .IgnoreQueryFilters()
            .Where(m => m.EventId == eventId)
            .Include(m => m.Reactions)
            .Include(m => m.Mentions)
            .AsSplitQuery()
            .OrderBy(m => m.CreatedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var epingles = await db.PinnedMessages
            .Where(p => p.EventId == eventId)
            .Select(p => p.MessageId)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var parIdentifiant = messages.ToDictionary(m => m.Id);

        return Result<MessagePage>.Success(new MessagePage(
        [
            .. messages.Select(m => Vue(
                m,
                moi.MemberId,
                noms,
                parIdentifiant,
                epingles.Contains(m.Id))),
        ]));
    }

    public async Task<Result<MessageView>> EnvoyerAsync(
        Guid eventId,
        MessageRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var corps = requete.Body?.Trim();

        // Un message sans texte ni pièce jointe ni sondage n'a rien à dire : l'accepter
        // remplirait le fil de lignes vides que personne ne peut supprimer sans savoir
        // à quoi elles correspondaient.
        if (string.IsNullOrEmpty(corps)
            && string.IsNullOrWhiteSpace(requete.AttachmentUrl)
            && requete.PollId is null)
        {
            return Empty;
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        var mentions = requete.MentionedMemberIds ?? [];

        // Citer quelqu'un d'un autre événement le notifierait d'une soirée à laquelle
        // il n'appartient pas.
        if (mentions.Any(id => membres.All(m => m.MemberId != id)))
        {
            return UnknownMention;
        }

        if (requete.ReplyToMessageId is { } cite)
        {
            var existe = await db.Messages
                .IgnoreQueryFilters()
                .AnyAsync(m => m.Id == cite && m.EventId == eventId, cancellationToken)
                .ConfigureAwait(false);

            if (!existe)
            {
                return UnknownReply;
            }
        }

        var message = new Message
        {
            Id = ids.NewId(),
            EventId = eventId,
            MemberId = moi.MemberId,
            Body = corps,
            AttachmentUrl = requete.AttachmentUrl,
            ReplyToMessageId = requete.ReplyToMessageId,
            PollId = requete.PollId,
            CreatedAt = clock.UtcNow,
        };

        foreach (var membre in mentions.Distinct())
        {
            message.Mentions.Add(new MessageMention
            {
                Id = ids.NewId(),
                MessageId = message.Id,
                MemberId = membre,
            });
        }

        db.Messages.Add(message);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return await VueSeuleAsync(eventId, message.Id, moi.MemberId, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<Result<MessageView>> ModifierAsync(
        Guid eventId,
        Guid messageId,
        MessageRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var message = await db.Messages
            .FirstOrDefaultAsync(
                m => m.Id == messageId && m.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (message is null)
        {
            return NotFound;
        }

        // Modifier le message d'un autre permettrait de lui faire dire le contraire de
        // ce qu'il a écrit. Même un organisateur ne peut que supprimer.
        if (message.MemberId != moi.MemberId)
        {
            return NotMine;
        }

        var corps = requete.Body?.Trim();

        if (string.IsNullOrEmpty(corps) && string.IsNullOrWhiteSpace(message.AttachmentUrl))
        {
            return Empty;
        }

        message.Body = corps;
        message.EditedAt = clock.UtcNow;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return await VueSeuleAsync(eventId, message.Id, moi.MemberId, cancellationToken)
            .ConfigureAwait(false);
    }

    /// <summary>
    /// Supprime un message. L'auteur, ou une personne qui gère l'événement.
    /// <para>
    /// Suppression logique : la place du message subsiste, sans son contenu. Les
    /// réponses qui le citent resteraient sinon incompréhensibles.
    /// </para>
    /// </summary>
    public async Task<Result> SupprimerAsync(
        Guid eventId,
        Guid messageId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var message = await db.Messages
            .FirstOrDefaultAsync(
                m => m.Id == messageId && m.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (message is null)
        {
            return NotFound;
        }

        if (message.MemberId != moi.MemberId && !moi.CanManage)
        {
            return NotMine;
        }

        message.DeletedAt = clock.UtcNow;
        message.Body = null;
        message.AttachmentUrl = null;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Pose ou retire une réaction (EF-MSG-03).
    /// <para>
    /// Interrupteur : la même réaction envoyée deux fois se retire. Deux appuis ne
    /// doivent pas produire deux pastilles, et l'index unique de la table l'interdirait
    /// de toute façon — autant que le geste soit prévisible.
    /// </para>
    /// </summary>
    public async Task<Result<MessageView>> BasculerReactionAsync(
        Guid eventId,
        Guid messageId,
        string emoji,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        if (string.IsNullOrWhiteSpace(emoji))
        {
            return EmojiRequired;
        }

        var message = await db.Messages
            .FirstOrDefaultAsync(
                m => m.Id == messageId && m.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (message is null)
        {
            return NotFound;
        }

        var existante = await db.MessageReactions
            .FirstOrDefaultAsync(
                r => r.MessageId == messageId
                    && r.MemberId == moi.MemberId
                    && r.Emoji == emoji,
                cancellationToken)
            .ConfigureAwait(false);

        if (existante is null)
        {
            db.MessageReactions.Add(new MessageReaction
            {
                Id = ids.NewId(),
                MessageId = messageId,
                MemberId = moi.MemberId,
                Emoji = emoji,
                CreatedAt = clock.UtcNow,
            });
        }
        else
        {
            db.MessageReactions.Remove(existante);
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return await VueSeuleAsync(eventId, messageId, moi.MemberId, cancellationToken)
            .ConfigureAwait(false);
    }

    // ---------------------------------------------------------------- épingles ----

    public async Task<Result<PinPage>> ListerEpinglesAsync(
        Guid eventId,
        Guid? folderId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var noms = await NomsAsync(eventId, cancellationToken).ConfigureAwait(false);

        var dossiers = await db.PinFolders
            .Where(f => f.EventId == eventId)
            .OrderBy(f => f.Name)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var epingles = await db.PinnedMessages
            .Where(p => p.EventId == eventId)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var identifiants = epingles.Select(p => p.MessageId).ToList();

        var messages = await db.Messages
            .IgnoreQueryFilters()
            .Where(m => identifiants.Contains(m.Id))
            .Include(m => m.Reactions)
            .Include(m => m.Mentions)
            .AsSplitQuery()
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var parIdentifiant = messages.ToDictionary(m => m.Id);
        var nomsDossiers = dossiers.ToDictionary(f => f.Id, f => f.Name);

        var retenues = folderId is null
            ? epingles
            : [.. epingles.Where(p => p.FolderId == folderId)];

        return Result<PinPage>.Success(new PinPage(
            [
                .. dossiers.Select(f => new PinFolderView(
                    f.Id,
                    f.Name,
                    epingles.Count(p => p.FolderId == f.Id))),
            ],
            [
                .. retenues
                    .Where(p => parIdentifiant.ContainsKey(p.MessageId))
                    .Select(p => new PinView(
                        p.Id,
                        p.FolderId,
                        p.FolderId is null ? null : nomsDossiers.GetValueOrDefault(p.FolderId.Value),
                        Vue(
                            parIdentifiant[p.MessageId],
                            moi.MemberId,
                            noms,
                            parIdentifiant,
                            pinned: true),
                        p.CreatedAt)),
            ]));
    }

    public async Task<Result<PinFolderView>> CreerDossierAsync(
        Guid eventId,
        string nom,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var propre = nom?.Trim();

        if (string.IsNullOrEmpty(propre))
        {
            return FolderNameRequired;
        }

        var existe = await db.PinFolders
            .AnyAsync(f => f.EventId == eventId && f.Name == propre, cancellationToken)
            .ConfigureAwait(false);

        // Deux dossiers « Musique » rendraient le rangement ambigu : on ne saurait
        // plus lequel on ouvre.
        if (existe)
        {
            return FolderExists;
        }

        var dossier = new PinFolder
        {
            Id = ids.NewId(),
            EventId = eventId,
            Name = propre,
            CreatedByMemberId = moi.MemberId,
            CreatedAt = clock.UtcNow,
        };

        db.PinFolders.Add(dossier);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result<PinFolderView>.Success(new PinFolderView(dossier.Id, dossier.Name, 0));
    }

    /// <summary>
    /// Supprime un dossier. Réservé à qui gère l'événement.
    /// <para>
    /// Un dossier partagé effacé fait disparaître les repères de tout le groupe. Les
    /// épingles qu'il contenait ne sont pas perdues : elles reviennent au rangement
    /// libre.
    /// </para>
    /// </summary>
    public async Task<Result> SupprimerDossierAsync(
        Guid eventId,
        Guid folderId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        if (!moi.CanManage)
        {
            return DomainError.Rule(
                "pin.folder_manage_only",
                "Seule une personne qui gère l'événement supprime un dossier.");
        }

        var dossier = await db.PinFolders
            .FirstOrDefaultAsync(
                f => f.Id == folderId && f.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (dossier is null)
        {
            return FolderNotFound;
        }

        db.PinFolders.Remove(dossier);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Épingle un message, avec ou sans dossier (EF-MSG-05).
    /// <para>
    /// Réépingler un message déjà épinglé le déplace au lieu d'échouer : c'est ainsi
    /// qu'on le range après coup.
    /// </para>
    /// </summary>
    public async Task<Result<PinView>> EpinglerAsync(
        Guid eventId,
        Guid messageId,
        Guid? folderId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var message = await db.Messages
            .IgnoreQueryFilters()
            .Include(m => m.Reactions)
            .Include(m => m.Mentions)
            .AsSplitQuery()
            .FirstOrDefaultAsync(
                m => m.Id == messageId && m.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (message is null)
        {
            return NotFound;
        }

        string? nomDossier = null;

        if (folderId is { } dossier)
        {
            var trouve = await db.PinFolders
                .FirstOrDefaultAsync(
                    f => f.Id == dossier && f.EventId == eventId,
                    cancellationToken)
                .ConfigureAwait(false);

            if (trouve is null)
            {
                return FolderNotFound;
            }

            nomDossier = trouve.Name;
        }

        var epingle = await db.PinnedMessages
            .FirstOrDefaultAsync(p => p.MessageId == messageId, cancellationToken)
            .ConfigureAwait(false);

        if (epingle is null)
        {
            epingle = new PinnedMessage
            {
                Id = ids.NewId(),
                EventId = eventId,
                MessageId = messageId,
                FolderId = folderId,
                PinnedByMemberId = moi.MemberId,
                CreatedAt = clock.UtcNow,
            };

            db.PinnedMessages.Add(epingle);
        }
        else
        {
            epingle.FolderId = folderId;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var noms = await NomsAsync(eventId, cancellationToken).ConfigureAwait(false);

        return Result<PinView>.Success(new PinView(
            epingle.Id,
            epingle.FolderId,
            nomDossier,
            Vue(message, moi.MemberId, noms, new Dictionary<Guid, Message>(), pinned: true),
            epingle.CreatedAt));
    }

    public async Task<Result> DesepinglerAsync(
        Guid eventId,
        Guid messageId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var epingle = await db.PinnedMessages
            .FirstOrDefaultAsync(
                p => p.MessageId == messageId && p.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (epingle is null)
        {
            return NotPinned;
        }

        db.PinnedMessages.Remove(epingle);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    // ------------------------------------------------------------------ aides ----

    private async Task<Dictionary<Guid, string>> NomsAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var membres = await membership.ListActiveAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        return membres.ToDictionary(m => m.MemberId, m => m.DisplayName);
    }

    private async Task<Result<MessageView>> VueSeuleAsync(
        Guid eventId,
        Guid messageId,
        Guid moi,
        CancellationToken cancellationToken)
    {
        var message = await db.Messages
            .IgnoreQueryFilters()
            .Include(m => m.Reactions)
            .Include(m => m.Mentions)
            .AsSplitQuery()
            .FirstAsync(m => m.Id == messageId, cancellationToken)
            .ConfigureAwait(false);

        var noms = await NomsAsync(eventId, cancellationToken).ConfigureAwait(false);

        var cites = new Dictionary<Guid, Message>();

        if (message.ReplyToMessageId is { } cite)
        {
            var origine = await db.Messages
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(m => m.Id == cite, cancellationToken)
                .ConfigureAwait(false);

            if (origine is not null)
            {
                cites[origine.Id] = origine;
            }
        }

        var epingle = await db.PinnedMessages
            .AnyAsync(p => p.MessageId == messageId, cancellationToken)
            .ConfigureAwait(false);

        return Result<MessageView>.Success(Vue(message, moi, noms, cites, epingle));
    }

    private static MessageView Vue(
        Message message,
        Guid moi,
        Dictionary<Guid, string> noms,
        Dictionary<Guid, Message> parIdentifiant,
        bool pinned)
    {
        var supprime = message.DeletedAt is not null;

        ReplyView? citation = null;

        if (message.ReplyToMessageId is { } cite
            && parIdentifiant.TryGetValue(cite, out var origine))
        {
            citation = new ReplyView(
                origine.Id,
                noms.GetValueOrDefault(origine.MemberId, "Quelqu'un"),
                Tronquer(origine.DeletedAt is null ? origine.Body : null));
        }

        return new MessageView(
            message.Id,
            message.MemberId,
            noms.GetValueOrDefault(message.MemberId, "Quelqu'un"),
            supprime ? null : message.Body,
            supprime ? null : message.AttachmentUrl,
            supprime ? null : message.PollId,
            citation,
            [
                .. message.Reactions
                    .GroupBy(r => r.Emoji)
                    .OrderBy(g => g.Key, StringComparer.Ordinal)
                    .Select(g => new ReactionView(
                        g.Key,
                        g.Count(),
                        g.Any(r => r.MemberId == moi))),
            ],
            [
                .. message.Mentions.Select(m => new MentionView(
                    m.MemberId,
                    noms.GetValueOrDefault(m.MemberId, "Quelqu'un"))),
            ],
            message.MemberId == moi,
            message.EditedAt is not null,
            supprime,
            pinned,
            message.CreatedAt);
    }

    private static string? Tronquer(string? corps) =>
        corps is not null && corps.Length > LongueurCitation
            ? corps[..LongueurCitation] + "…"
            : corps;
}
