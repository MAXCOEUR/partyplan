namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Formule d'un compte, telle que les autres modules ont besoin de la connaître.
/// <para>
/// Réduite à un booléen à dessein : un module applique un quota, il n'a pas à connaître
/// une échéance, un moyen de paiement ni un cycle de vie. Le lot 4.1 remplacera la
/// colonne <c>premium_until</c> par une table d'abonnements (ADR 0008) sans que ce
/// contrat change de forme, donc sans toucher à ses appelants.
/// </para>
/// </summary>
public interface IFormuleCompte
{
    /// <summary>Vrai si la formule payante est active à cet instant.</summary>
    Task<bool> EstAbonneAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>
    /// Formules de plusieurs comptes, en une requête.
    /// <para>
    /// Nécessaire dès qu'un écran affiche plusieurs comptes : un appel par ligne referait
    /// autant de requêtes que de lignes, et le coût suivrait la taille de la liste. Les
    /// identifiants inconnus sont absents du résultat, ce qui vaut « non abonné ».
    /// </para>
    /// </summary>
    Task<IReadOnlyDictionary<Guid, bool>> EstAbonneManyAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken);
}
