namespace PartyPlan.Modules.Auth.Domain;

/// <summary>
/// Jeton à usage unique, valable 15 minutes (RG-AUTH-03). Sert la vérification
/// d'adresse et la réinitialisation de mot de passe : un seul mécanisme pour les deux
/// besoins (ADR 0005).
/// </summary>
public abstract class OneTimeToken
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    /// <summary>Condensé du jeton. La valeur en clair n'existe que dans le courriel envoyé.</summary>
    public string TokenHash { get; set; } = string.Empty;

    public DateTimeOffset ExpiresAt { get; set; }

    public DateTimeOffset? ConsumedAt { get; set; }

    public System.Net.IPAddress? RequestedIp { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public bool IsUsable(DateTimeOffset now) => ConsumedAt is null && ExpiresAt > now;
}

/// <summary>Jeton de réinitialisation de mot de passe (EF-AUTH-04).</summary>
public sealed class PasswordResetToken : OneTimeToken
{
    /// <summary>
    /// Vrai lorsque la réinitialisation a été déclenchée par un administrateur
    /// (EF-ADM-04). Conservé pour la lisibilité du journal d'audit.
    /// </summary>
    public bool RequestedByAdmin { get; set; }
}

/// <summary>
/// Jeton de vérification d'adresse (EF-AUTH-03). Porte <see cref="NewEmail"/> lorsqu'il
/// s'agit d'un changement d'adresse (EF-USR-03) : la nouvelle adresse ne prend effet
/// qu'à la consommation du jeton.
/// </summary>
public sealed class EmailVerificationToken : OneTimeToken
{
    public string? NewEmail { get; set; }
}
