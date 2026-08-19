namespace PartyPlan.Modules.Events.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Entrée du fil d'activité (EF-FIL-01). En lecture seule et non modifiable, y compris
/// par le propriétaire de l'événement (RG-FIL-02) : c'est la trace de référence en cas
/// de litige sur les montants.
/// </summary>
public sealed class ActivityEntry : IEventScoped
{
    public Guid Id { get; init; }

    public Guid EventId { get; init; }

    /// <summary>Auteur de l'action. Nul pour une action système, par exemple un rappel automatique.</summary>
    public Guid? MemberId { get; init; }

    /// <summary>
    /// Nom de l'auteur au moment de l'action. Figé volontairement : un changement de nom
    /// ultérieur ne doit pas réécrire l'histoire (RG-USR-04).
    /// </summary>
    public string ActorName { get; init; } = string.Empty;

    public string Kind { get; init; } = string.Empty;

    /// <summary>Contexte au format JSON : libellé d'article, montant, ancienne et nouvelle valeur.</summary>
    public string? Payload { get; init; }

    public DateTimeOffset CreatedAt { get; init; }
}

/// <summary>
/// Catégories du fil d'activité. Les dix catégories exigées par RG-FIL-01 sont
/// couvertes ; ne jamais renommer une valeur déjà écrite en base.
/// </summary>
public static class ActivityKinds
{
    public const string MemberJoined = "member.joined";
    public const string MemberStatusChanged = "member.status_changed";
    public const string ItemCreated = "item.created";
    public const string ItemDeleted = "item.deleted";
    public const string ItemClaimed = "item.claimed";
    public const string ItemPurchased = "item.purchased";
    public const string ExpenseCreated = "expense.created";
    public const string ExpenseUpdated = "expense.updated";
    public const string SettlementMarked = "settlement.marked";
    public const string EventScheduleChanged = "event.schedule_changed";
    public const string EventDateOrPlaceChanged = "event.date_or_place_changed";
}
