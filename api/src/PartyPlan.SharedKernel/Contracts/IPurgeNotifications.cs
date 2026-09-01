namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Purge de l'historique des notifications. Contrat public du module Notifications,
/// consommé par l'ordonnanceur de l'Infrastructure, qui ne doit pas lire la table
/// <c>notifications</c> lui-même (règle 6).
/// </summary>
public interface IPurgeNotifications
{
    /// <summary>
    /// Supprime les notifications déjà envoyées dont la date d'inscription dépasse la
    /// durée de conservation, et rend le nombre de lignes retirées.
    /// </summary>
    Task<int> PurgerAsync(DateTimeOffset maintenant, CancellationToken cancellationToken);
}
