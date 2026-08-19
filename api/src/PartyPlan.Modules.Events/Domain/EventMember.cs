namespace PartyPlan.Modules.Events.Domain;

using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Enums;

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
}
