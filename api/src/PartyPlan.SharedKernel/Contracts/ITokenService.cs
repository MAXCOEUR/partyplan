namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Enums;

/// <summary>Émission des jetons de session. Contrat public du module Auth.</summary>
public interface ITokenService
{
    /// <summary>Jeton d'accès d'un compte.</summary>
    AccessToken CreateAccessToken(Guid userId, PlatformRole role, Guid sessionId);

    /// <summary>
    /// Jeton d'accès d'un invité sans compte, restreint à un seul événement
    /// (EF-INV-04). Il ne porte aucun identifiant de compte.
    /// </summary>
    AccessToken CreateGuestToken(Guid eventId, Guid memberId);

    /// <summary>
    /// Jeton de rafraîchissement : une valeur en clair remise au client, et son
    /// condensé, seul élément conservé en base.
    /// </summary>
    RefreshToken CreateRefreshToken();

    /// <summary>Condensé d'un jeton de rafraîchissement présenté par un client.</summary>
    string HashRefreshToken(string plainToken);

    /// <summary>Jeton à usage unique pour un lien envoyé par courriel (RG-AUTH-03).</summary>
    OneTimeSecret CreateOneTimeSecret();
}

public sealed record AccessToken(string Value, DateTimeOffset ExpiresAt);

public sealed record RefreshToken(string Value, string Hash, DateTimeOffset ExpiresAt);

public sealed record OneTimeSecret(string Value, string Hash, DateTimeOffset ExpiresAt);
