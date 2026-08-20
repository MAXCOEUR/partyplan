namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Ce qu'un membre a avancé et ce qu'il doit, en centimes, sur les dépenses non
/// supprimées.
/// </summary>
public sealed record LedgerLine(Guid MemberId, long AdvancedCents, long OwedCents);

/// <summary>
/// Grand livre des dépenses. Contrat public du module Expenses, consommé par
/// Settlements pour calculer les soldes (§6.3).
/// <para>
/// Les montants sont exprimés en <b>centimes entiers</b>, jamais en décimal : c'est
/// l'unité de calcul imposée par le §6.1, et convertir aux frontières rouvrirait la
/// porte aux erreurs d'arrondi que la répartition au centime sert à fermer.
/// </para>
/// </summary>
public interface IExpenseLedger
{
    Task<IReadOnlyList<LedgerLine>> GetAsync(Guid eventId, CancellationToken cancellationToken);
}
