namespace PartyPlan.Modules.Users.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Groupe permanent (EF-GRP-01). Réutilisable d'un événement à l'autre.</summary>
public sealed class Group : IAuditable
{
    public Guid Id { get; set; }

    public Guid OwnerUserId { get; set; }

    public string Name { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public ICollection<GroupMember> Members { get; } = new List<GroupMember>();
}

/// <summary>
/// Appartenance à un groupe. Le retrait est horodaté et non destructif : les événements
/// passés ne doivent pas être affectés (EF-GRP-03).
/// </summary>
public sealed class GroupMember
{
    public Guid Id { get; set; }

    public Guid GroupId { get; set; }

    /// <summary>Nul pour un contact ajouté par son seul nom, sans compte associé.</summary>
    public Guid? UserId { get; set; }

    public string DisplayName { get; set; } = string.Empty;

    public string? Email { get; set; }

    public DateTimeOffset AddedAt { get; set; }

    public DateTimeOffset? RemovedAt { get; set; }
}
