namespace PartyPlan.Infrastructure.Security;

using System.Security.Cryptography;
using Microsoft.Extensions.Options;
using PartyPlan.SharedKernel.Contracts;

public sealed class SecurityOptions
{
    public const string SectionName = "Security";

    /// <summary>Longueur de clé exigée, en octets.</summary>
    public const int KeyBytes = 32;

    /// <summary>
    /// Clé de chiffrement des secrets, encodée en base64 sur 32 octets.
    /// <para>
    /// Distincte de la clé de signature des jetons : une clé compromise ne doit pas
    /// donner à la fois la capacité de forger des sessions et celle de lire les seconds
    /// facteurs.
    /// </para>
    /// </summary>
    public string EncryptionKey { get; set; } = string.Empty;
}

/// <summary>
/// Chiffrement AES-GCM des secrets stockés.
/// <para>
/// AES-GCM et non AES-CBC : le mode authentifié détecte toute altération du texte
/// chiffré. Sans authentification, un secret modifié en base produirait silencieusement
/// un secret différent, et l'utilisateur perdrait l'accès à son compte sans qu'aucune
/// trace n'explique pourquoi.
/// </para>
/// <para>
/// Format stocké : <c>v1.nonce.chiffré.étiquette</c>, chaque partie en base64url. Le
/// numéro de version permet une rotation d'algorithme sans deviner le format.
/// </para>
/// </summary>
public sealed class AesGcmSecretProtector : ISecretProtector
{
    private const string Version = "v1";
    private const int NonceBytes = 12;
    private const int TagBytes = 16;

    private readonly byte[] _key;

    public AesGcmSecretProtector(IOptions<SecurityOptions> options)
    {
        ArgumentNullException.ThrowIfNull(options);

        var brut = options.Value.EncryptionKey;

        if (string.IsNullOrWhiteSpace(brut))
        {
            throw new InvalidOperationException(
                $"{SecurityOptions.SectionName}:EncryptionKey est absente. "
                + "Générer une clé : openssl rand -base64 32");
        }

        byte[] cle;

        try
        {
            cle = Convert.FromBase64String(brut);
        }
        catch (FormatException exception)
        {
            throw new InvalidOperationException(
                $"{SecurityOptions.SectionName}:EncryptionKey n'est pas du base64 valide.",
                exception);
        }

        if (cle.Length != SecurityOptions.KeyBytes)
        {
            throw new InvalidOperationException(
                $"{SecurityOptions.SectionName}:EncryptionKey doit faire exactement "
                + $"{SecurityOptions.KeyBytes} octets, soit 44 caractères en base64. "
                + "Générer une clé : openssl rand -base64 32");
        }

        _key = cle;
    }

    public string Protect(ReadOnlySpan<byte> secret)
    {
        // Un nonce aléatoire par chiffrement : le réutiliser avec la même clé briserait
        // entièrement la confidentialité d'AES-GCM.
        var nonce = RandomNumberGenerator.GetBytes(NonceBytes);
        var chiffre = new byte[secret.Length];
        var etiquette = new byte[TagBytes];

        using var aes = new AesGcm(_key, TagBytes);
        aes.Encrypt(nonce, secret, chiffre, etiquette);

        return string.Join('.',
            Version,
            Convert.ToBase64String(nonce),
            Convert.ToBase64String(chiffre),
            Convert.ToBase64String(etiquette));
    }

    public bool TryUnprotect(string? protectedValue, out byte[] secret)
    {
        secret = [];

        if (string.IsNullOrWhiteSpace(protectedValue))
        {
            return false;
        }

        var parties = protectedValue.Split('.');

        if (parties.Length != 4 || parties[0] != Version)
        {
            return false;
        }

        byte[] nonce;
        byte[] chiffre;
        byte[] etiquette;

        try
        {
            nonce = Convert.FromBase64String(parties[1]);
            chiffre = Convert.FromBase64String(parties[2]);
            etiquette = Convert.FromBase64String(parties[3]);
        }
        catch (FormatException)
        {
            return false;
        }

        if (nonce.Length != NonceBytes || etiquette.Length != TagBytes)
        {
            return false;
        }

        var clair = new byte[chiffre.Length];

        try
        {
            using var aes = new AesGcm(_key, TagBytes);
            aes.Decrypt(nonce, chiffre, etiquette, clair);
        }
        catch (CryptographicException)
        {
            // Étiquette invalide : la valeur a été altérée, ou la clé a changé. Dans les
            // deux cas, refuser plutôt que renvoyer des octets arbitraires.
            return false;
        }

        secret = clair;

        return true;
    }
}
