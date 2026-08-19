namespace PartyPlan.Modules.Shopping.Domain;

using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Enums;

/// <summary>Article de la liste de courses (EF-CRS-01).</summary>
public sealed class ShoppingItem : IEventScoped, IAuditable, ISoftDeletable
{
    public Guid Id { get; set; }

    public Guid EventId { get; set; }

    public string Name { get; set; } = string.Empty;

    public decimal Quantity { get; set; } = 1m;

    public string? Unit { get; set; }

    public ShoppingCategory Category { get; set; } = ShoppingCategory.Other;

    /// <summary>
    /// Attributaire unique (RG-CRS-01). Le contrôle d'unicité est effectué en
    /// transaction côté serveur, jamais par l'interface.
    /// </summary>
    public Guid? AssignedMemberId { get; set; }

    public DateTimeOffset? AssignedAt { get; set; }

    /// <summary>Quantité réellement obtenue (EF-CRS-05). Inférieure à <see cref="Quantity"/> en cas d'achat partiel.</summary>
    public decimal? PurchasedQuantity { get; set; }

    /// <summary>Prix estimé. N'entre jamais dans les calculs financiers (RG-CRS-03).</summary>
    public decimal? EstimatedPrice { get; set; }

    /// <summary>Prix réellement payé. Sa saisie engendre une dépense (EF-CRS-07).</summary>
    public decimal? ActualPrice { get; set; }

    public bool IsPurchased { get; set; }

    public string? Note { get; set; }

    public int Position { get; set; }

    public Guid CreatedByMemberId { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public bool IsClaimed => AssignedMemberId is not null;

    /// <summary>Reliquat à obtenir, affiché en cas d'achat partiel (RG-CRS-02).</summary>
    public decimal RemainingQuantity => Math.Max(0m, Quantity - (PurchasedQuantity ?? 0m));
}
