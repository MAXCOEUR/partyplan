namespace PartyPlan.Modules.Settlements.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Remboursement déclaré effectué (EF-RMB-03). Seuls les remboursements réalisés sont
/// persistés : les soldes et les règlements proposés sont recalculés à la demande
/// (RG-RMB-02).
/// </summary>
public sealed class Settlement : IEventScoped
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public Guid FromMemberId { get; set; }

    public Guid ToMemberId { get; set; }

    public decimal Amount { get; set; }

    public DateTimeOffset SettledAt { get; set; }

    public Guid MarkedByMemberId { get; set; }

    /// <summary>Confirmation par le créditeur (EF-RMB-07). Nulle tant qu'elle n'a pas eu lieu.</summary>
    public DateTimeOffset? ConfirmedAt { get; set; }

    /// <summary>Annulation d'un marquage erroné (EF-RMB-04).</summary>
    public DateTimeOffset? CancelledAt { get; set; }

    /// <summary>Seuls les règlements non annulés entrent dans le calcul suivant (RG-RMB-03).</summary>
    public bool IsEffective => CancelledAt is null;
}
