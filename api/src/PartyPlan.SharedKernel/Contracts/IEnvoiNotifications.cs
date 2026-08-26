namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Passe d'envoi des notifications dues. Contrat public du module Notifications,
/// consommé par l'ordonnanceur de l'Infrastructure, qui ne doit pas lire la table
/// <c>notifications</c> lui-même (règle 6).
/// </summary>
public interface IEnvoiNotifications
{
    /// <summary>
    /// Envoie ce qui est dû à cet instant, et rend le nombre parti. Ne lève jamais pour
    /// un envoi qui échoue : la ligne est horodatée malgré tout, sinon la boucle la
    /// réessaierait à chaque réveil.
    /// </summary>
    Task<int> EnvoyerLesDuesAsync(DateTimeOffset maintenant, CancellationToken cancellationToken);
}
