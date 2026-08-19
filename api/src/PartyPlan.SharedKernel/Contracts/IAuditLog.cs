namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Journal d'audit des actions d'administration (RG-ADM-06). Contrat public du module
/// Administration, propriétaire de la table.
/// </summary>
public interface IAuditLog
{
    /// <summary>
    /// Enregistre une action. En ajout seul : aucune méthode de modification ni de
    /// suppression n'est exposée, et la base l'interdit également (NF-SEC-08).
    /// </summary>
    Task RecordAsync(
        string action,
        Guid? targetUserId,
        string? reason,
        object? metadata,
        CancellationToken cancellationToken);

    /// <summary>
    /// Enregistre une action dépourvue d'auteur humain : amorçage au démarrage, tâche
    /// planifiée. L'auteur est alors le système, et non un compte usurpé — attribuer ces
    /// actions à un administrateur existant rendrait le journal mensonger.
    /// </summary>
    Task RecordSystemAsync(
        string action,
        Guid? targetUserId,
        object? metadata,
        CancellationToken cancellationToken);
}
