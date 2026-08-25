namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Membre tel qu'il apparaît dans la liste des invités (EF-PRES-04).</summary>
public sealed record MemberView(
    Guid Id,
    string DisplayName,
    string? AvatarUrl,
    string Status,
    string? ArrivalTime,
    string? DepartureTime,
    int ExtraGuests,
    string Role,
    bool HasAccount,
    bool IsMe);

/// <summary>Déclaration de présence (EF-PRES-01, EF-PRES-02, EF-PRES-06).</summary>
public sealed record SetAttendanceRequest(
    string Status,
    TimeOnly? ArrivalTime,
    TimeOnly? DepartureTime,
    int? ExtraGuests);

/// <summary>
/// Présences (EF-PRES-01 à EF-PRES-06).
/// <para>
/// Chacun ne modifie que son propre statut : l'organisateur relance, il ne répond pas à
/// la place des autres.
/// </para>
/// </summary>
public sealed class AttendanceService(
    IEventsDbContext db,
    ICurrentUser currentUser,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IUserIdentityLookup identites)
{
    /// <summary>Plafond d'accompagnants. Au-delà, il s'agit d'un autre événement.</summary>
    public const int MaxExtraGuests = 10;

    public static readonly DomainError UnknownStatus = DomainError.Validation(
        "attendance.unknown_status",
        "Statut inconnu. Valeurs acceptées : Going, Maybe, NotGoing, Late, EarlyLeave.");

    public static readonly DomainError NotAMember = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError TooManyGuests = DomainError.Validation(
        "attendance.too_many_guests",
        $"Au maximum {MaxExtraGuests} accompagnants.");

    public async Task<Result<IReadOnlyList<MemberView>>> ListerAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var moi = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (moi is null)
        {
            return NotAMember;
        }

        var membres = await db.EventMembers
            .Where(m => m.EventId == eventId && m.RemovedAt == null)
            .OrderBy(m => m.JoinedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        // Une seule requête pour toutes les photos, plutôt qu'un appel par membre.
        var photos = await identites
            .FindManyAsync(
                [.. membres.Where(m => m.UserId is not null).Select(m => m.UserId!.Value)],
                cancellationToken)
            .ConfigureAwait(false);

        return Result<IReadOnlyList<MemberView>>.Success(
        [
            .. membres.Select(m => new MemberView(
                m.Id,
                m.DisplayName,
                m.UserId is { } compte && photos.TryGetValue(compte, out var identite)
                    ? identite.AvatarUrl
                    : null,
                m.Status.ToString(),
                m.ArrivalTime?.ToString("HH\\hmm"),
                m.DepartureTime?.ToString("HH\\hmm"),
                m.ExtraGuests,
                m.Role.ToString(),
                m.UserId is not null,
                m.Id == moi.Id)),
        ]);
    }

    public async Task<Result<MemberView>> DeclarerAsync(
        Guid eventId,
        SetAttendanceRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        if (!Enum.TryParse<EventMemberStatus>(requete.Status, out var statut)
            || statut == EventMemberStatus.Unknown)
        {
            return UnknownStatus;
        }

        if (requete.ExtraGuests is < 0 or > MaxExtraGuests)
        {
            return TooManyGuests;
        }

        var membre = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (membre is null)
        {
            return NotAMember;
        }

        var ancien = membre.Status;

        membre.Status = statut;
        membre.ArrivalTime = requete.ArrivalTime;
        membre.DepartureTime = requete.DepartureTime;

        if (requete.ExtraGuests is { } accompagnants)
        {
            membre.ExtraGuests = (short)accompagnants;
        }

        if (ancien != statut)
        {
            db.ActivityEntries.Add(new ActivityEntry
            {
                Id = ids.NewId(),
                EventId = eventId,
                MemberId = membre.Id,
                ActorName = membre.DisplayName,
                Kind = ActivityKinds.MemberStatusChanged,
                Payload = $"{{\"de\":\"{ancien}\",\"vers\":\"{statut}\"}}",
                CreatedAt = clock.UtcNow,
            });
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var identite = membre.UserId is { } compte
            ? await identites.FindAsync(compte, cancellationToken).ConfigureAwait(false)
            : null;

        var vue = new MemberView(
            membre.Id,
            membre.DisplayName,
            identite?.AvatarUrl,
            membre.Status.ToString(),
            membre.ArrivalTime?.ToString("HH\\hmm"),
            membre.DepartureTime?.ToString("HH\\hmm"),
            membre.ExtraGuests,
            membre.Role.ToString(),
            membre.UserId is not null,
            true);

        // L'état résultant et non l'identifiant seul (RG-RT-02) : c'est exactement ce
        // que l'endpoint renvoie, donc rien à construire en plus.
        await diffusion
            .PublierAsync(eventId, MessagesTempsReel.MembreStatutChange, vue, cancellationToken)
            .ConfigureAwait(false);

        return vue;
    }

    /// <summary>Exclusion d'un membre par le propriétaire ou un administrateur (RG-ROLE-01).</summary>
    public async Task<Result> ExclureAsync(
        Guid eventId,
        Guid memberId,
        CancellationToken cancellationToken)
    {
        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (acteur is null)
        {
            return NotAMember;
        }

        var cible = await db.EventMembers
            .FirstOrDefaultAsync(m => m.Id == memberId && m.EventId == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (cible is null)
        {
            return DomainError.NotFound("member.not_found", "Ce participant est introuvable.");
        }

        var autorise = EventMember.CanRemove(acteur, cible);
        if (autorise.IsFailure)
        {
            return autorise;
        }

        // RG-ROLE-03 : la ligne n'est jamais supprimée. Les dépenses, achats et dettes du
        // membre subsistent, sans quoi les comptes des autres deviendraient faux.
        cible.RemovedAt = clock.UtcNow;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Pas d'état à envoyer : le membre a disparu de la liste, et son identifiant
        // suffit à savoir quoi retirer.
        await diffusion
            .PublierAsync(
                eventId,
                MessagesTempsReel.MembreRetire,
                new { memberId = cible.Id },
                cancellationToken)
            .ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Transfère la propriété de l'événement (RG-ROLE-02).
    /// <para>
    /// L'ancien propriétaire devient administrateur et non membre ordinaire : il vient
    /// d'organiser l'événement, lui retirer tout droit dans le même geste serait absurde.
    /// </para>
    /// </summary>
    public async Task<Result> TransfererProprieteAsync(
        Guid eventId,
        Guid memberId,
        CancellationToken cancellationToken)
    {
        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (acteur is null)
        {
            return NotAMember;
        }

        var cible = await db.EventMembers
            .FirstOrDefaultAsync(m => m.Id == memberId && m.EventId == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (cible is null)
        {
            return DomainError.NotFound("member.not_found", "Ce participant est introuvable.");
        }

        var autorise = EventMember.CanTransferOwnership(acteur, cible);
        if (autorise.IsFailure)
        {
            return autorise;
        }

        // L'ordre compte : un index d'unicité garantit un seul propriétaire actif par
        // événement. Promouvoir avant de rétrograder violerait la contrainte.
        acteur.Role = EventMemberRole.Admin;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        cible.Role = EventMemberRole.Owner;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>Quitte l'événement (EF-EVT-06, RG-ROLE-02).</summary>
    public async Task<Result> QuitterAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var membre = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (membre is null)
        {
            return NotAMember;
        }

        var autorise = EventMember.CanLeave(membre);
        if (autorise.IsFailure)
        {
            return autorise;
        }

        membre.RemovedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await diffusion
            .PublierAsync(
                eventId,
                MessagesTempsReel.MembreRetire,
                new { memberId = membre.Id },
                cancellationToken)
            .ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>Membre correspondant au compte appelant.</summary>
    private Task<EventMember?> MembreCourantAsync(Guid eventId, CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } compte)
        {
            return Task.FromResult<EventMember?>(null);
        }

        return db.EventMembers.FirstOrDefaultAsync(
            m => m.EventId == eventId && m.UserId == compte && m.RemovedAt == null,
            cancellationToken);
    }
}
