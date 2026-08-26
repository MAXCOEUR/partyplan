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
