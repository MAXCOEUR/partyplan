namespace PartyPlan.Modules.Polls.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Polls.Domain;
using PartyPlan.Modules.Polls.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Option d'un sondage, avec son décompte.</summary>
public sealed record PollOptionView(Guid Id, string Label, int Votes, bool Mine);

/// <summary>Sondage tel que l'interface l'affiche.</summary>
public sealed record PollView(
    Guid Id,
    string Question,
    bool AllowMultiple,
    bool Closed,
    bool IVoted,
    int Voters,
    string CreatedByDisplayName,
    DateTimeOffset CreatedAt,
    IReadOnlyList<PollOptionView> Options);

/// <summary>Sondages d'un événement.</summary>
public sealed record PollPage(IReadOnlyList<PollView> Items);

/// <summary>Création d'un sondage (EF-SDG-01).</summary>
public sealed record PollRequest(
    string Question,
    IReadOnlyList<string> Options,
    bool AllowMultiple);

/// <summary>
/// Sondages d'un événement (EF-SDG-01 à EF-SDG-04).
/// <para>
/// Un sondage naît dans la discussion — c'est là qu'on se demande quoi faire — et se
/// retrouve dans un écran à lui : remonté par cinquante messages, il devient
/// introuvable.
/// </para>
/// <para>
/// Le vote est identifié par la ligne de membre, jamais par un compte : un invité sans
/// compte vote comme les autres (EF-INV-04).
/// </para>
/// </summary>
public sealed class PollService(
    IPollsDbContext db,
    IEventMembership membership,
    IPollAnnouncement annonce,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IFileNotifications notifications,
    IReveilNotifications reveil)
{
    /// <summary>Nombre minimal d'options. Une seule réponse n'est pas un choix.</summary>
    private const int OptionsMinimales = 2;

    /// <summary>Au-delà, un sondage ne se lit plus : il se subit.</summary>
    private const int OptionsMaximales = 10;

    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NotFound = DomainError.NotFound(
        "poll.not_found",
        "Ce sondage est introuvable.");

    public static readonly DomainError QuestionRequired = DomainError.Validation(
        "poll.question_required",
        "Pose une question.");

    public static readonly DomainError OptionsRequired = DomainError.Validation(
        "poll.options_required",
        $"Donne au moins {OptionsMinimales} réponses possibles.");

    public static readonly DomainError TooManyOptions = DomainError.Validation(
        "poll.too_many_options",
        $"Pas plus de {OptionsMaximales} réponses.");

    public static readonly DomainError Closed = DomainError.Rule(
        "poll.closed",
        "Ce sondage est clos.");

    public static readonly DomainError SingleChoice = DomainError.Rule(
        "poll.single_choice",
        "Ce sondage n'accepte qu'une seule réponse.");

    public static readonly DomainError UnknownOption = DomainError.Validation(
        "poll.unknown_option",
        "Une des réponses choisies n'appartient pas à ce sondage.");

    public static readonly DomainError NotMine = DomainError.Rule(
        "poll.not_mine",
        "Seule la personne qui a lancé le sondage, ou l'organisateur, peut le clore.");

    /// <summary>
    /// Diffuse un sondage et renvoie le résultat.
    /// <para>
    /// Un vote qui n'apparaît qu'au rechargement fait voter deux fois sur la même
    /// question : c'est la raison pour laquelle les sondages sont dans la liste, alors
    /// que le §9 les avait omis.
    /// </para>
    /// </summary>
    private async Task<Result<PollView>> DiffuserAsync(
        Guid eventId,
        string message,
        Result<PollView> resultat,
        CancellationToken cancellationToken)
    {
        if (resultat.IsSuccess)
        {
            await diffusion
                .PublierAsync(eventId, message, resultat.Value!, cancellationToken)
                .ConfigureAwait(false);
        }

        return resultat;
    }

    public async Task<Result<PollPage>> ListerAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        var noms = membres.ToDictionary(m => m.MemberId, m => m.DisplayName);

        var sondages = await db.Polls
            .Where(p => p.EventId == eventId)
            .Include(p => p.Options)
            .AsSplitQuery()
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var identifiants = sondages.Select(p => p.Id).ToList();

        var votes = await db.PollVotes
            .Where(v => identifiants.Contains(v.PollId))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        // Les sondages ouverts d'abord, puis les plus récents : on ouvre cet écran pour
        // répondre, pas pour relire ce qui est tranché.
        var ordonnes = sondages
            .OrderBy(p => p.ClosedAt is null ? 0 : 1)
            .ThenByDescending(p => p.CreatedAt)
            .ToList();

        return Result<PollPage>.Success(new PollPage(
        [
            .. ordonnes.Select(p => Vue(p, votes, moi.MemberId, noms)),
        ]));
    }

    public async Task<Result<PollView>> CreerAsync(
        Guid eventId,
        PollRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var question = requete.Question?.Trim();

        if (string.IsNullOrEmpty(question))
        {
            return QuestionRequired;
        }

        var libelles = (requete.Options ?? [])
            .Select(o => o?.Trim() ?? string.Empty)
            .Where(o => o.Length > 0)
            .Distinct(StringComparer.CurrentCultureIgnoreCase)
            .ToList();

        if (libelles.Count < OptionsMinimales)
        {
            return OptionsRequired;
        }

        if (libelles.Count > OptionsMaximales)
        {
            return TooManyOptions;
        }

        var maintenant = clock.UtcNow;

        var sondage = new Poll
        {
            Id = ids.NewId(),
            EventId = eventId,
            Question = question,
            AllowMultiple = requete.AllowMultiple,
            IsAnonymous = false,
            CreatedByMemberId = moi.MemberId,
            CreatedAt = maintenant,
            UpdatedAt = maintenant,
        };

        for (var position = 0; position < libelles.Count; position++)
        {
            sondage.Options.Add(new PollOption
            {
                Id = ids.NewId(),
                PollId = sondage.Id,
                Label = libelles[position],
                Position = position,
            });
        }

        db.Polls.Add(sondage);

        foreach (var membre in await membership.ListActiveAsync(eventId, cancellationToken))
        {
            if (membre.MemberId == moi.MemberId || membre.UserId is not { } compte)
            {
                continue;
            }

            notifications.Enfiler(new NotificationAEnvoyer(
                compte,
                eventId,
                NotificationCategories.PollNew,
                "Nouveau sondage",
                sondage.Question,
                DestinationsNotification.Sondages(eventId),
                clock.UtcNow,
                $"{eventId}:{NotificationCategories.PollNew}:{compte}:{sondage.Id}"));
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Après validation, jamais avant : une transaction en échec ne doit réveiller
        // personne pour un sondage qui n'existera pas.
        reveil.Reveiller();

        // L'annonce passe par le contrat public du module Messages : Polls n'accède
        // jamais à la table des messages (ADR 0002).
        await annonce
            .AnnounceAsync(eventId, moi.MemberId, sondage.Id, question, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.SondageCree,
            Result<PollView>.Success(
            Vue(sondage, [], moi.MemberId, new Dictionary<Guid, string>
            {
                [moi.MemberId] = moi.DisplayName,
            })),
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Enregistre les choix d'un membre, en remplaçant les précédents (EF-SDG-02).
    /// <para>
    /// Une liste vide annule son vote : c'est le geste de qui s'est trompé, et il ne
    /// mérite pas un endpoint de plus.
    /// </para>
    /// </summary>
    public async Task<Result<PollView>> VoterAsync(
        Guid eventId,
        Guid pollId,
        IReadOnlyList<Guid> optionIds,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var sondage = await db.Polls
            .Include(p => p.Options)
            .AsSplitQuery()
            .FirstOrDefaultAsync(
                p => p.Id == pollId && p.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (sondage is null)
        {
            return NotFound;
        }

        if (sondage.ClosedAt is not null)
        {
            return Closed;
        }

        var choix = (optionIds ?? []).Distinct().ToList();

        if (!sondage.AllowMultiple && choix.Count > 1)
        {
            return SingleChoice;
        }

        if (choix.Any(id => sondage.Options.All(o => o.Id != id)))
        {
            return UnknownOption;
        }

        var anciens = await db.PollVotes
            .Where(v => v.PollId == pollId && v.MemberId == moi.MemberId)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        db.PollVotes.RemoveRange(anciens);

        foreach (var option in choix)
        {
            db.PollVotes.Add(new PollVote
            {
                Id = ids.NewId(),
                PollId = pollId,
                OptionId = option,
                MemberId = moi.MemberId,
                CreatedAt = clock.UtcNow,
            });
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var vue = await RelireAsync(eventId, pollId, moi.MemberId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.SondageVote,
            vue,
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Clôt un sondage (EF-SDG-03). Réservé à son auteur ou à qui gère l'événement :
    /// clore la question d'un autre couperait la parole.
    /// </summary>
    public async Task<Result<PollView>> ClorAsync(
        Guid eventId,
        Guid pollId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var sondage = await db.Polls
            .FirstOrDefaultAsync(
                p => p.Id == pollId && p.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (sondage is null)
        {
            return NotFound;
        }

        if (sondage.CreatedByMemberId != moi.MemberId && !moi.CanManage)
        {
            return NotMine;
        }

        sondage.ClosedAt = clock.UtcNow;
        sondage.UpdatedAt = clock.UtcNow;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var vue = await RelireAsync(eventId, pollId, moi.MemberId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.SondageVote,
            vue,
            cancellationToken).ConfigureAwait(false);
    }

    public async Task<Result> SupprimerAsync(
        Guid eventId,
        Guid pollId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        if (moi is null)
        {
            return EventNotFound;
        }

        var sondage = await db.Polls
            .FirstOrDefaultAsync(
                p => p.Id == pollId && p.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        if (sondage is null)
        {
            return NotFound;
        }

        if (sondage.CreatedByMemberId != moi.MemberId && !moi.CanManage)
        {
            return NotMine;
        }

        sondage.DeletedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    // ------------------------------------------------------------------ aides ----

    private async Task<Result<PollView>> RelireAsync(
        Guid eventId,
        Guid pollId,
        Guid moiId,
        CancellationToken cancellationToken)
    {
        var sondage = await db.Polls
            .Include(p => p.Options)
            .AsSplitQuery()
            .FirstAsync(p => p.Id == pollId, cancellationToken)
            .ConfigureAwait(false);

        var votes = await db.PollVotes
            .Where(v => v.PollId == pollId)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var membres = await membership.ListActiveAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        return Result<PollView>.Success(
            Vue(sondage, votes, moiId, membres.ToDictionary(m => m.MemberId, m => m.DisplayName)));
    }

    private static PollView Vue(
        Poll sondage,
        List<PollVote> votes,
        Guid moiId,
        Dictionary<Guid, string> noms)
    {
        var siens = votes.Where(v => v.PollId == sondage.Id).ToList();

        return new PollView(
            sondage.Id,
            sondage.Question,
            sondage.AllowMultiple,
            sondage.ClosedAt is not null,
            siens.Any(v => v.MemberId == moiId),
            siens.Select(v => v.MemberId).Distinct().Count(),
            noms.GetValueOrDefault(sondage.CreatedByMemberId, "Quelqu'un"),
            sondage.CreatedAt,
            [
                .. sondage.Options
                    .OrderBy(o => o.Position)
                    .Select(o => new PollOptionView(
                        o.Id,
                        o.Label,
                        siens.Count(v => v.OptionId == o.Id),
                        siens.Any(v => v.OptionId == o.Id && v.MemberId == moiId))),
            ]);
    }
}
