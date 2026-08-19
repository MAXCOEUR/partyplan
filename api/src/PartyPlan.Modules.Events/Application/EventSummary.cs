namespace PartyPlan.Modules.Events.Application;

/// <summary>
/// Vue de synthèse d'un événement, telle que renvoyée par l'API. Type distinct de
/// l'entité : le contrat public ne doit pas suivre mécaniquement le schéma de la base.
/// </summary>
public sealed record EventSummary(
    Guid Id,
    string Name,
    string? Description,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    string? Address,
    string? CoverImageUrl,
    int MemberCount,
    int PresentCount,
    int MaybeCount,
    bool JoinEnabled);
