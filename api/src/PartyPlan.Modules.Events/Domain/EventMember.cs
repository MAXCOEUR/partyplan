namespace PartyPlan.Modules.Events.Domain;

using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Appartenance d'une personne à un événement. <see cref="UserId"/> est nul pour un
/// invité sans compte (EF-INV-04) : aucune fonctionnalité ne doit dépendre de sa présence.
/// </summary>
public sealed class EventMember : IEventScoped
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public Guid? UserId { get; set; }

    /// <summary>
    /// Nom affiché dans cet événement. Conservé même après changement du nom de compte,
    /// afin qu'un membre ne puisse pas se dissocier d'une dette (RG-USR-04).
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    public EventMemberStatus Status { get; set; } = EventMemberStatus.Unknown;

    public TimeOnly? ArrivalTime { get; set; }

    public TimeOnly? DepartureTime { get; set; }

    /// <summary>Accompagnants annoncés (EF-PRES-06).</summary>
    public short ExtraGuests { get; set; }

    public EventMemberRole Role { get; set; } = EventMemberRole.Member;

    /// <summary>
    /// Empreinte du jeton de session invité. Seul support de la liaison vers un compte
    /// créé ultérieurement : jamais le prénom (RG-AUTH-07).
    /// </summary>
    public string? GuestSessionHash { get; set; }

    public DateTimeOffset JoinedAt { get; set; }

    /// <summary>
    /// Exclusion horodatée. Les dépenses, achats et dettes du membre subsistent
    /// (RG-ROLE-03) : la ligne n'est jamais supprimée.
    /// </summary>
    public DateTimeOffset? RemovedAt { get; set; }

    public bool IsActive => RemovedAt is null;

    /// <summary>Comptabilisé comme présent : RG-PRES-02.</summary>
    public bool CountsAsPresent => Status is EventMemberStatus.Going
        or EventMemberStatus.Late
        or EventMemberStatus.EarlyLeave;

    /// <summary>
    /// Nombre de têtes apportées : la personne et ses accompagnants (EF-PRES-06).
    /// L'organisateur achète pour des têtes, pas pour des comptes.
    /// </summary>
    public int Heads => CountsAsPresent ? 1 + Math.Max(0, (int)ExtraGuests) : 0;

    /// <summary>Peut modifier l'événement, inviter, exclure (§3.2).</summary>
    public bool CanManageEvent =>
        IsActive && Role is EventMemberRole.Owner or EventMemberRole.Admin;

    /// <summary>Seul le propriétaire supprime l'événement (RG-ROLE-01).</summary>
    public bool CanDeleteEvent => IsActive && Role == EventMemberRole.Owner;

    public static readonly DomainError CannotRemoveOwner = DomainError.Forbidden(
        "event.cannot_remove_owner",
        "Le propriétaire de l'événement ne peut pas être exclu.");

    public static readonly DomainError CannotRemoveSelf = DomainError.Rule(
        "event.cannot_remove_self",
        "Pour partir, utilise « quitter l'événement ».");

    public static readonly DomainError NotAllowedToRemove = DomainError.Forbidden(
        "event.not_allowed_to_remove",
        "Seuls le propriétaire et les administrateurs peuvent exclure un membre.");

    public static readonly DomainError OwnerMustTransfer = DomainError.Rule(
        "event.owner_must_transfer",
        "Transfère la propriété de l'événement avant de le quitter.");

    /// <summary>
    /// Vérifie qu'un membre peut en exclure un autre (RG-ROLE-01).
    /// <para>
    /// L'auto-exclusion est refusée explicitement : quitter un événement est une autre
    /// opération, qui vérifie le transfert de propriété.
    /// </para>
    /// </summary>
    public static Result CanRemove(EventMember actor, EventMember target)
    {
        ArgumentNullException.ThrowIfNull(actor);
        ArgumentNullException.ThrowIfNull(target);

        if (actor.Id == target.Id)
        {
            return CannotRemoveSelf;
        }

        if (!actor.CanManageEvent)
        {
            return NotAllowedToRemove;
        }

        return target.Role == EventMemberRole.Owner ? CannotRemoveOwner : Result.Success();
    }

    /// <summary>
    /// Vérifie qu'un membre peut quitter l'événement (RG-ROLE-02). Sans cette règle, un
    /// événement pourrait se retrouver sans propriétaire, donc impossible à administrer
    /// ou à supprimer.
    /// </summary>
    public static Result CanLeave(EventMember member)
    {
        ArgumentNullException.ThrowIfNull(member);

        return member.Role == EventMemberRole.Owner ? OwnerMustTransfer : Result.Success();
    }
}

/// <summary>
/// Décompte de présence d'un événement (EF-PRES-05).
/// <para>
/// Type dédié plutôt que trois entiers baladeurs : les trois valeurs se calculent
/// ensemble et se lisent ensemble, et les confondre est facile.
/// </para>
/// </summary>
public sealed record AttendanceCount(int Invited, int Present, int Maybe, int Heads)
{
    public static AttendanceCount From(IEnumerable<EventMember> members)
    {
        ArgumentNullException.ThrowIfNull(members);

        var actifs = members.Where(m => m.IsActive).ToList();

        return new AttendanceCount(
            actifs.Count,
            actifs.Count(m => m.CountsAsPresent),
            actifs.Count(m => m.Status == EventMemberStatus.Maybe),
            actifs.Sum(m => m.Heads));
    }
}
