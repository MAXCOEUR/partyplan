namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Rattachement des participations d'invité à un compte (EF-AUTH-11).
/// <para>
/// Exposé par le module Events et consommé par Users. Le module Users n'accède jamais à
/// <c>event_members</c> : la frontière est contrôlée en intégration continue.
/// </para>
/// <para>
/// La méthode reçoit le <b>jeton brut</b> et non son empreinte. L'algorithme d'empreinte
/// reste ainsi un détail interne d'Events : l'exposer dans le noyau partagé le figerait
/// en contrat public et permettrait à n'importe quel module de forger une empreinte.
/// </para>
/// </summary>
public interface IGuestMembershipLinking
{
    /// <summary>
    /// Rattache au compte toute participation portant l'empreinte de ce jeton.
    /// La liaison se fait sur le jeton, jamais sur le prénom (RG-AUTH-07) : deux
    /// homonymes ne doivent jamais fusionner.
    /// </summary>
    /// <returns>Nombre de participations rattachées. Zéro n'est pas une erreur.</returns>
    Task<int> LinkAsync(Guid userId, string guestToken, CancellationToken cancellationToken);
}
