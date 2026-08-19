namespace PartyPlan.Modules.Users.Domain;

using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Compte utilisateur (§7.2). Un compte n'est pas nécessaire pour participer à un
/// événement : voir <c>EventMember.UserId</c> nullable et EF-INV-04.
/// </summary>
public sealed class User : IAuditable, ISoftDeletable
{
    public Guid Id { get; set; }

    /// <summary>Adresse e-mail, insensible à la casse (<c>citext</c>). Nulle pour un compte non encore réclamé.</summary>
    public string? Email { get; set; }

    public DateTimeOffset? EmailVerifiedAt { get; set; }

    /// <summary>
    /// Empreinte Argon2id (RG-AUTH-02). Nulle pour un compte créé par connexion tierce,
    /// qui peut en définir une par le parcours de réinitialisation (RG-AUTH-08).
    /// </summary>
    public string? PasswordHash { get; set; }

    public DateTimeOffset? PasswordChangedAt { get; set; }

    /// <summary>Imposé au compte administrateur amorcé (RG-ADM-10).</summary>
    public bool MustChangePassword { get; set; }

    /// <summary>Secret TOTP chiffré au repos. Jamais renvoyé par l'API après l'enrôlement.</summary>
    public string? TotpSecretEncrypted { get; set; }

    public DateTimeOffset? TotpEnabledAt { get; set; }

    /// <summary>Rôle de portée « instance » (§3.1). N'accorde aucun droit dans un événement : RG-ADM-01.</summary>
    public PlatformRole PlatformRole { get; set; } = PlatformRole.User;

    public string DisplayName { get; set; } = string.Empty;

    /// <summary>Adresse de la photo de profil, contenant une empreinte du contenu (RG-USR-03).</summary>
    public string? AvatarUrl { get; set; }

    public string Locale { get; set; } = "fr-FR";

    public string Timezone { get; set; } = "Europe/Paris";

    public string? GoogleSubject { get; set; }

    public string? AppleSubject { get; set; }

    public DateTimeOffset? PremiumUntil { get; set; }

    public DateTimeOffset? LastLoginAt { get; set; }

    /// <summary>Compteur d'échecs consécutifs, base du ralentissement croissant (RG-AUTH-05).</summary>
    public short FailedLoginCount { get; set; }

    public DateTimeOffset? SuspendedAt { get; set; }

    public string? SuspensionReason { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }

    public DateTimeOffset? DeletedAt { get; set; }

    public bool IsSuspended => SuspendedAt is not null;

    public bool IsPremium(DateTimeOffset now) => PremiumUntil is not null && PremiumUntil > now;
}
