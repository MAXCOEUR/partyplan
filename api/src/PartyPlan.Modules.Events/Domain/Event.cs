namespace PartyPlan.Modules.Events.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Événement (§7.2). Privé par défaut et sans exception (RG-EVT-01).</summary>
public sealed class Event : IAuditable, ISoftDeletable
{
    /// <summary>Durée implicite lorsque aucune fin n'est renseignée (EF-EVT-02).</summary>
    public static readonly TimeSpan ImplicitDuration = TimeSpan.FromHours(12);

    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public DateTimeOffset StartsAt { get; set; }

    public DateTimeOffset? EndsAt { get; set; }

    public string? Address { get; set; }

    /// <summary>Stockées mais non alimentées au MVP : la géolocalisation est reportée (RG-EVT-03).</summary>
    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    public string? CoverImageUrl { get; set; }

    /// <summary>Jeton du lien d'invitation, 128 bits minimum, non déductible de l'identifiant (RG-INV-01).</summary>
    public string InviteToken { get; set; } = string.Empty;

    /// <summary>Code court saisissable, six caractères sur un alphabet non ambigu (RG-INV-02).</summary>
    public string ShortCode { get; set; } = string.Empty;

    /// <summary>Faux lorsque l'organisateur a fermé les nouvelles arrivées (EF-INV-06).</summary>
    public bool JoinEnabled { get; set; } = true;

    public Guid CreatedByUserId { get; set; }

    public DateTimeOffset? ArchivedAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public ICollection<EventMember> Members { get; } = new List<EventMember>();

    /// <summary>Fin effective : la date renseignée, sinon le début majoré de 12 heures (EF-EVT-02).</summary>
    public DateTimeOffset EffectiveEndsAt => EndsAt ?? StartsAt + ImplicitDuration;

    public bool IsPast(DateTimeOffset now) => EffectiveEndsAt < now;
}
