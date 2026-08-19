namespace PartyPlan.Modules.Auth.Application;

using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Konscious.Security.Cryptography;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Hachage des mots de passe par Argon2id (RG-AUTH-02).
/// <para>
/// Paramètres retenus : 64 Mo de mémoire, 3 passes, parallélisme 2. Ils suivent les
/// recommandations de l'OWASP pour Argon2id, et représentent quelques dizaines de
/// millisecondes par vérification — coût négligeable à l'échelle d'une connexion,
/// prohibitif à l'échelle d'une attaque par dictionnaire.
/// </para>
/// <para>
/// Le format stocké porte ses propres paramètres : une évolution ultérieure du coût
/// n'invalide pas les empreintes existantes.
/// </para>
/// </summary>
public sealed class PasswordHasher : IPasswordHasher
{
    private const int MemoryKb = 65536;
    private const int Iterations = 3;
    private const int Parallelism = 2;
    private const int SaltBytes = 16;
    private const int HashBytes = 32;
    private const string Prefix = "argon2id";

    public string Hash(string password)
    {
        ArgumentException.ThrowIfNullOrEmpty(password);

        var salt = RandomNumberGenerator.GetBytes(SaltBytes);
        var hash = Compute(password, salt, MemoryKb, Iterations, Parallelism, HashBytes);

        return string.Join('$',
            Prefix,
            MemoryKb.ToString(CultureInfo.InvariantCulture),
            Iterations.ToString(CultureInfo.InvariantCulture),
            Parallelism.ToString(CultureInfo.InvariantCulture),
            Convert.ToBase64String(salt),
            Convert.ToBase64String(hash));
    }

    /// <summary>
    /// Vérifie un mot de passe. La comparaison est à temps constant : une comparaison
    /// ordinaire laisserait fuir de l'information par sa durée.
    /// </summary>
    public bool Verify(string password, string? stored)
    {
        if (string.IsNullOrEmpty(password) || string.IsNullOrEmpty(stored))
        {
            return false;
        }

        var parties = stored.Split('$');
        if (parties.Length != 6 || parties[0] != Prefix)
        {
            return false;
        }

        if (!int.TryParse(parties[1], CultureInfo.InvariantCulture, out var memory)
            || !int.TryParse(parties[2], CultureInfo.InvariantCulture, out var iterations)
            || !int.TryParse(parties[3], CultureInfo.InvariantCulture, out var parallelism))
        {
            return false;
        }

        byte[] salt;
        byte[] attendu;

        try
        {
            salt = Convert.FromBase64String(parties[4]);
            attendu = Convert.FromBase64String(parties[5]);
        }
        catch (FormatException)
        {
            return false;
        }

        var calcule = Compute(password, salt, memory, iterations, parallelism, attendu.Length);

        return CryptographicOperations.FixedTimeEquals(calcule, attendu);
    }

    /// <summary>
    /// Vrai lorsque l'empreinte a été produite avec des paramètres plus faibles que les
    /// paramètres courants. Permet de réhacher silencieusement à la connexion suivante.
    /// </summary>
    public bool NeedsRehash(string? stored)
    {
        if (string.IsNullOrEmpty(stored))
        {
            return false;
        }

        var parties = stored.Split('$');

        return parties.Length != 6
               || parties[0] != Prefix
               || !int.TryParse(parties[1], CultureInfo.InvariantCulture, out var memory)
               || memory < MemoryKb;
    }

    private static byte[] Compute(
        string password,
        byte[] salt,
        int memoryKb,
        int iterations,
        int parallelism,
        int length)
    {
        using var argon = new Argon2id(Encoding.UTF8.GetBytes(password))
        {
            Salt = salt,
            MemorySize = memoryKb,
            Iterations = iterations,
            DegreeOfParallelism = parallelism,
        };

        return argon.GetBytes(length);
    }
}
