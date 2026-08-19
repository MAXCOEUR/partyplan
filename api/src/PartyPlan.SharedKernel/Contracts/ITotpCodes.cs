namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Mots de passe à usage unique fondés sur le temps (RFC 6238). Contrat public du
/// module Auth, propriétaire des mécanismes de sécurité.
/// <para>
/// Exposé par contrat et non par référence directe : le module Users, qui possède les
/// comptes, ne référence aucun autre module (ADR 0002).
/// </para>
/// </summary>
public interface ITotpCodes
{
    /// <summary>Génère un secret de la longueur recommandée par la RFC 4226.</summary>
    byte[] GenerateSecret();

    /// <summary>Encode un secret pour la saisie manuelle dans une application d'authentification.</summary>
    string ToBase32(byte[] secret);

    /// <summary>Vérifie un code, en tolérant la dérive d'horloge d'un pas de part et d'autre.</summary>
    bool Verify(byte[] secret, string? code, DateTimeOffset instant);

    /// <summary>Construit l'URI <c>otpauth</c> à encoder dans le QR code.</summary>
    string BuildUri(string issuer, string account, byte[] secret);
}
