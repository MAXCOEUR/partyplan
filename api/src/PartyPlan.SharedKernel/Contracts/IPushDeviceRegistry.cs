namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Mise au rebut d'un appareil. Contrat public du module Notifications, consommé par
/// l'émetteur de notifications de l'Infrastructure.
/// <para>
/// Exposé par contrat et non par accès direct : <c>push_devices</c> appartient au module
/// Notifications, et la règle 6 interdit d'y écrire depuis ailleurs. C'est le même motif
/// que <c>IExpenseFromPurchase</c> ou <c>IEventMembership</c>.
/// </para>
/// </summary>
public interface IPushDeviceRegistry
{
    /// <summary>
    /// Désactive l'appareil portant ce jeton. Idempotent : un jeton déjà désactivé ou
    /// inconnu ne produit rien.
    /// </summary>
    Task DisableAsync(string token, string raison, CancellationToken cancellationToken);
}
