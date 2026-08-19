namespace PartyPlan.Modules.Auth.Application;

using System.Buffers.Binary;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;

/// <summary>
/// Mots de passe à usage unique fondés sur le temps, selon la RFC 6238.
/// <para>
/// Implémenté ici plutôt qu'emprunté à une bibliothèque : l'algorithme tient en trente
/// lignes, il est entièrement spécifié, et les vecteurs de test officiels de la RFC
/// permettent de le prouver — preuve plus forte que la confiance accordée à un paquet.
/// Une dépendance de moins sur un chemin de sécurité.
/// </para>
/// </summary>
public static class Totp
{
    /// <summary>Durée d'un pas de temps, en secondes. Trente secondes : valeur universelle.</summary>
    public const int StepSeconds = 30;

    public const int Digits = 6;

    /// <summary>
    /// Tolérance de part et d'autre du pas courant, en nombre de pas.
    /// <para>
    /// Un pas d'avance et un pas de retard : les horloges de téléphone dérivent, et
    /// refuser un code saisi à la seconde où il expire serait une source d'échecs
    /// inexplicables pour l'utilisateur. Deux pas de plus n'apporteraient rien qu'une
    /// fenêtre d'attaque plus large.
    /// </para>
    /// </summary>
    public const int ToleranceSteps = 1;

    public const int SecretBytes = 20;

    /// <summary>Génère un secret de 160 bits, longueur recommandée par la RFC 4226.</summary>
    public static byte[] GenerateSecret() => RandomNumberGenerator.GetBytes(SecretBytes);

    /// <summary>Calcule le code d'un pas donné.</summary>
    public static string Compute(ReadOnlySpan<byte> secret, long step)
    {
        Span<byte> compteur = stackalloc byte[8];
        BinaryPrimitives.WriteInt64BigEndian(compteur, step);

        Span<byte> empreinte = stackalloc byte[HMACSHA1.HashSizeInBytes];

        // CA5350 : HMAC-SHA1 est imposé par l'interopérabilité. La RFC 6238 le spécifie,
        // et c'est ce qu'implémentent toutes les applications d'authentification —
        // proposer SHA-256 rendrait les codes incompatibles avec Google Authenticator,
        // Aegis ou 1Password. La faiblesse connue de SHA-1 porte sur la résistance aux
        // collisions, qui n'intervient pas dans un code d'authentification de message :
        // HMAC-SHA1 reste sûr dans cet usage.
#pragma warning disable CA5350
        HMACSHA1.HashData(secret, compteur, empreinte);
#pragma warning restore CA5350

        // Troncature dynamique de la RFC 4226 : les quatre bits de poids faible du
        // dernier octet désignent l'offset de lecture.
        var offset = empreinte[^1] & 0x0F;

        var binaire = ((empreinte[offset] & 0x7F) << 24)
                      | (empreinte[offset + 1] << 16)
                      | (empreinte[offset + 2] << 8)
                      | empreinte[offset + 3];

        var modulo = (int)Math.Pow(10, Digits);

        return (binaire % modulo).ToString(CultureInfo.InvariantCulture).PadLeft(Digits, '0');
    }

    public static string Compute(ReadOnlySpan<byte> secret, DateTimeOffset instant) =>
        Compute(secret, StepOf(instant));

    public static long StepOf(DateTimeOffset instant) =>
        instant.ToUnixTimeSeconds() / StepSeconds;

    /// <summary>
    /// Vérifie un code, en tolérant la dérive d'horloge.
    /// <para>
    /// La comparaison est à temps constant : une comparaison de chaînes ordinaire
    /// laisserait fuir la position du premier chiffre erroné.
    /// </para>
    /// </summary>
    public static bool Verify(ReadOnlySpan<byte> secret, string? code, DateTimeOffset instant)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return false;
        }

        var normalise = code.Replace(" ", string.Empty, StringComparison.Ordinal).Trim();

        if (normalise.Length != Digits || !normalise.All(char.IsAsciiDigit))
        {
            return false;
        }

        var attendu = Encoding.ASCII.GetBytes(normalise);
        var pasCourant = StepOf(instant);
        var valide = false;

        for (var decalage = -ToleranceSteps; decalage <= ToleranceSteps; decalage++)
        {
            var candidat = Encoding.ASCII.GetBytes(Compute(secret, pasCourant + decalage));

            // Aucune sortie anticipée : le temps de vérification ne doit pas dépendre du
            // pas qui a permis la validation.
            valide |= CryptographicOperations.FixedTimeEquals(candidat, attendu);
        }

        return valide;
    }

    /// <summary>
    /// Construit l'URI <c>otpauth</c> à encoder dans le QR code.
    /// <para>
    /// L'émetteur est répété dans le libellé et en paramètre : les applications
    /// d'authentification n'en lisent pas toutes le même.
    /// </para>
    /// </summary>
    public static string BuildUri(string issuer, string account, ReadOnlySpan<byte> secret)
    {
        var emetteur = Uri.EscapeDataString(issuer);
        var compte = Uri.EscapeDataString(account);

        return $"otpauth://totp/{emetteur}:{compte}"
               + $"?secret={Base32.Encode(secret)}"
               + $"&issuer={emetteur}"
               + $"&algorithm=SHA1"
               + $"&digits={Digits}"
               + $"&period={StepSeconds}";
    }
}
