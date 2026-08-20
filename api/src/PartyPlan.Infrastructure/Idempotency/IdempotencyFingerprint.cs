namespace PartyPlan.Infrastructure.Idempotency;

using System.Security.Cryptography;
using System.Text;

/// <summary>
/// Empreinte et validation des clés d'idempotence (§8.1).
/// <para>
/// Sans idempotence, un double appui sur « enregistrer la dépense » crée deux dépenses
/// et fausse tous les soldes de l'événement. Sur réseau mobile, ce double envoi est
/// courant, non exceptionnel.
/// </para>
/// </summary>
public static class IdempotencyFingerprint
{
    /// <summary>Longueur maximale de la clé, alignée sur la colonne.</summary>
    public const int MaxKeyLength = 128;

    /// <summary>
    /// Empreinte du corps de la requête. Une même clé présentée avec un corps différent
    /// est un conflit, non une réémission : la distinction repose sur cette empreinte.
    /// </summary>
    public static string Compute(string? body) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(body ?? string.Empty)));

    public static bool IsValidKey(string? key) =>
        !string.IsNullOrWhiteSpace(key) && key.Length <= MaxKeyLength;
}
