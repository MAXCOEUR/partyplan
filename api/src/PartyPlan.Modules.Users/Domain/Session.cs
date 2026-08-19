namespace PartyPlan.Modules.Users.Domain;

/// <summary>
/// Session persistée, afin de pouvoir être révoquée (EF-AUTH-10, EF-ADM-05).
/// Un jeton d'accès seul, sans registre de sessions, ne peut pas être révoqué avant
/// son expiration.
/// </summary>
public sealed class Session
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    /// <summary>Condensé du jeton de rafraîchissement. La valeur en clair n'est jamais stockée.</summary>
    public string RefreshTokenHash { get; set; } = string.Empty;

    /// <summary>Libellé de l'appareil, présenté dans la liste des sessions actives.</summary>
    public string? DeviceLabel { get; set; }

    public string? UserAgent { get; set; }

    public System.Net.IPAddress? IpAddress { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset LastSeenAt { get; set; }

    public DateTimeOffset ExpiresAt { get; set; }

    public DateTimeOffset? RevokedAt { get; set; }

    public bool IsActive(DateTimeOffset now) => RevokedAt is null && ExpiresAt > now;
}
