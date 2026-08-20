namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Création d'une dépense à partir d'un achat (EF-CRS-07). Contrat public du module
/// Expenses, consommé par Shopping.
/// <para>
/// C'est le seul point par lequel une liste de courses engendre une dépense : dupliquer
/// la création côté Shopping ferait deux chemins d'écriture pour la même règle, et
/// l'assiette pourrait diverger.
/// </para>
/// </summary>
public interface IExpenseFromPurchase
{
    /// <summary>
    /// Crée la dépense d'un article acheté, ou met à jour son montant si elle existe
    /// déjà. L'opération est donc idempotente : ressaisir un prix ne crée pas une
    /// seconde dépense.
    /// </summary>
    Task<Guid> UpsertAsync(
        Guid eventId,
        Guid shoppingItemId,
        string label,
        decimal amount,
        Guid paidByMemberId,
        CancellationToken cancellationToken);

    /// <summary>Supprime logiquement la dépense issue d'un article, s'il en existe une.</summary>
    Task RemoveForItemAsync(
        Guid eventId,
        Guid shoppingItemId,
        CancellationToken cancellationToken);

    /// <summary>Une dépense est-elle rattachée à cet article ? (EF-CRS-08)</summary>
    Task<bool> ExistsForItemAsync(
        Guid eventId,
        Guid shoppingItemId,
        CancellationToken cancellationToken);
}
