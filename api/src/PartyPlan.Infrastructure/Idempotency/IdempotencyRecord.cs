namespace PartyPlan.Infrastructure.Idempotency;

/// <summary>
/// Trace d'une requête de création déjà traitée (§8.1). Sans elle, un double appui sur
/// « enregistrer la dépense » créerait deux dépenses et fausserait tous les soldes.
/// </summary>
public sealed class IdempotencyRecord
{
    public Guid Id { get; set; }

    /// <summary>Valeur de l'en-tête <c>Idempotency-Key</c> fournie par le client.</summary>
    public string Key { get; set; } = string.Empty;

    /// <summary>Appelant, afin qu'une clé d'un utilisateur n'en masque pas une autre.</summary>
    public Guid? UserId { get; set; }

    public string Endpoint { get; set; } = string.Empty;

    /// <summary>Empreinte du corps de la requête : une même clé avec un corps différent est un conflit.</summary>
    public string RequestHash { get; set; } = string.Empty;

    public int StatusCode { get; set; }

    /// <summary>Réponse renvoyée à l'identique lors d'une réémission.</summary>
    public string? ResponseBody { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }
}
