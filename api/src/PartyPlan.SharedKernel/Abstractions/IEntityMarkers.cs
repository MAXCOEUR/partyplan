namespace PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Entité rattachée à un événement. Toute entité portant ce marqueur est filtrée
/// par le cloisonnement global (RG-SEC-01) : c'est le marqueur, et non la présence
/// d'une jointure, qui déclenche le filtre.
/// </summary>
public interface IEventScoped
{
    Guid EventId { get; }
}

/// <summary>Entité à effacement logique (§7.1).</summary>
public interface ISoftDeletable
{
    DateTimeOffset? DeletedAt { get; set; }
}

/// <summary>Entité horodatée automatiquement à l'écriture.</summary>
public interface IAuditable
{
    DateTimeOffset CreatedAt { get; set; }

    DateTimeOffset UpdatedAt { get; set; }
}
