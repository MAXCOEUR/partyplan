namespace PartyPlan.Modules.Expenses.Domain;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Dépense réellement payée par un membre (EF-DEP-01).</summary>
public sealed class Expense : IEventScoped, IAuditable, ISoftDeletable
{
    /// <summary>Plafond du montant (RG-DEP-01).</summary>
    public const decimal MaxAmount = 99_999.99m;

    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public string Label { get; set; } = string.Empty;

    /// <summary>Montant en euros, strictement positif (RG-DEP-01).</summary>
    public decimal Amount { get; set; }

    public Guid PaidByMemberId { get; set; }

    /// <summary>Article de courses à l'origine de la dépense (EF-DEP-07). Nul pour une dépense libre.</summary>
    public Guid? ShoppingItemId { get; set; }

    public string? ReceiptUrl { get; set; }

    public DateTimeOffset SpentAt { get; set; }

    public Guid CreatedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    /// <summary>Effacement logique : les soldes sont recalculés, la trace subsiste (RG-DEP-05).</summary>
    public DateTimeOffset? DeletedAt { get; set; }

    public ICollection<ExpenseParticipant> Participants { get; } = new List<ExpenseParticipant>();

    public ICollection<ExpenseRevision> Revisions { get; } = new List<ExpenseRevision>();
}

/// <summary>
/// Participation d'un membre à une dépense. <see cref="AmountCents"/> est figé au calcul :
/// la répartition reste stable même si l'algorithme évolue, et l'invariant IV-01
/// devient vérifiable par simple requête (§7.2).
/// </summary>
public sealed class ExpenseParticipant
{
    public Guid ExpenseId { get; set; }

    public Guid MemberId { get; set; }

    /// <summary>Poids dans la répartition, strictement positif. Vaut 1 par défaut (§6.2).</summary>
    public int Share { get; set; } = 1;

    /// <summary>Part attribuée, en centimes. La somme des parts égale exactement le montant (IV-01).</summary>
    public int AmountCents { get; set; }
}

/// <summary>
/// Historique des modifications d'une dépense (RG-DEP-04). Conservé pour toute la vie
/// de l'événement : c'est ce qui permet de trancher un litige sur un montant.
/// </summary>
public sealed class ExpenseRevision
{
    public Guid Id { get; init; }

    public Guid ExpenseId { get; init; }

    public Guid EditedByMemberId { get; init; }

    public decimal PreviousAmount { get; init; }

    /// <summary>Assiette précédente, au format JSON : identifiants de membres et parts.</summary>
    public string PreviousParticipants { get; init; } = string.Empty;

    public DateTimeOffset CreatedAt { get; init; }
}
