namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// État des règlements d'un événement. Contrat public du module Settlements, consommé
/// par Events pour appliquer RG-EVT-02 : un événement dont des dettes restent en
/// suspens ne se supprime pas sans confirmation renforcée.
/// </summary>
public interface ISettlementStatus
{
    /// <summary>Reste-t-il au moins un solde non nul ?</summary>
    Task<bool> HasPendingAsync(Guid eventId, CancellationToken cancellationToken);
}
