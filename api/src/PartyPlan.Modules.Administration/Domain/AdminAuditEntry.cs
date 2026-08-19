namespace PartyPlan.Modules.Administration.Domain;

/// <summary>
/// Entrée du journal d'audit (RG-ADM-06). Table en ajout seul : aucune propriété
/// n'est modifiable après création, et le rôle applicatif ne dispose ni de
/// <c>UPDATE</c> ni de <c>DELETE</c> sur cette table (NF-SEC-08).
/// </summary>
public sealed class AdminAuditEntry
{
    public Guid Id { get; init; }

    public Guid ActorUserId { get; init; }

    /// <summary>
    /// Adresse de l'auteur recopiée à l'écriture, afin que le journal reste lisible
    /// après suppression de son compte.
    /// </summary>
    public string ActorEmail { get; init; } = string.Empty;

    public Guid? TargetUserId { get; init; }

    /// <summary>Nature de l'action, par exemple <c>user.suspended</c>.</summary>
    public string Action { get; init; } = string.Empty;

    /// <summary>Motif saisi. Obligatoire pour une suspension (EF-ADM-06).</summary>
    public string? Reason { get; init; }

    public System.Net.IPAddress? IpAddress { get; init; }

    /// <summary>Contexte libre au format JSON : valeurs avant et après, par exemple.</summary>
    public string? Metadata { get; init; }

    public DateTimeOffset CreatedAt { get; init; }
}
