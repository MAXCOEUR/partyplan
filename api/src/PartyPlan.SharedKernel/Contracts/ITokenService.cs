namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Enums;

/// <summary>Émission des jetons de session. Contrat public du module Auth.</summary>
public interface ITokenService
{
    /// <summary>
    /// Jeton d'accès d'un compte.
    /// <para>
    /// Il porte l'état de sécurité du compte — rôle plateforme, mot de passe à changer —
    /// afin que les gardes d'autorisation soient évaluées sans requête en base à chaque
    /// appel.
    /// </para>
    /// </summary>
    AccessToken CreateAccessToken(
        Guid userId,
        PlatformRole role,
        Guid sessionId,
        bool mustChangePassword);

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
