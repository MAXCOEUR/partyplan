namespace PartyPlan.Modules.Auth.Application;

using System.Globalization;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Politique de mot de passe (RG-AUTH-01).
/// <para>
/// Deux règles seulement : douze caractères au minimum, et absence de la liste des mots
/// de passe compromis. Pas d'exigence de composition, pas d'expiration périodique —
/// ces contraintes poussent aux variantes prévisibles et aux notes autocollantes, ce que
/// l'ANSSI et la CNIL déconseillent désormais.
/// </para>
/// </summary>
public sealed class PasswordPolicy : IPasswordPolicy
{
    public const int MinLength = 12;
    public const int MaxLength = 256;

    /// <summary>
    /// Longueur du condensé conservé, en caractères hexadécimaux. Quarante-huit bits
    /// pour quelques dizaines de milliers d'entrées : la probabilité de collision est
    /// négligeable, et une collision ferait de toute façon refuser un mot de passe
    /// légitime — jamais accepter un mot de passe compromis.
    /// </summary>
    public const int CondenseLength = 12;

    private static readonly Lazy<HashSet<string>> CompromisedHashes = new(Charger);

    public static readonly DomainError TooShort = DomainError.Validation(
        "password.too_short",
        $"Le mot de passe doit contenir au moins {MinLength} caractères.");

    public static readonly DomainError TooLong = DomainError.Validation(
        "password.too_long",
        $"Le mot de passe ne peut pas dépasser {MaxLength} caractères.");

    public static readonly DomainError Compromised = DomainError.Validation(
        "password.compromised",
        "Ce mot de passe figure dans une liste de mots de passe divulgués. Choisis-en un autre.");

    /// <summary>Nombre de condensés chargés. Exposé pour que les tests vérifient le chargement.</summary>
    public static int CompromisedCount => CompromisedHashes.Value.Count;

    public Result Validate(string? password)
    {
        if (password is null || password.Length < MinLength)
        {
            return TooShort;
        }

        if (password.Length > MaxLength)
        {
            return TooLong;
        }

        return IsCompromised(password) ? Compromised : Result.Success();
    }

    /// <summary>
    /// Recherche par condensé tronqué. Une collision ferait au pire refuser un mot de
    /// passe légitime : jamais accepter un mot de passe compromis.
    /// </summary>
    public static bool IsCompromised(string password)
    {
        var digest = Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(password)))
            .ToLower(CultureInfo.InvariantCulture)[..CondenseLength];

        return CompromisedHashes.Value.Contains(digest);
    }

    private static HashSet<string> Charger()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var nom = assembly.GetManifestResourceNames()
            .SingleOrDefault(n => n.EndsWith("mots-de-passe-compromis.txt", StringComparison.Ordinal))
            ?? throw new InvalidOperationException(
                "La liste des mots de passe compromis est absente de l'assemblage (RG-AUTH-01).");

        using var flux = assembly.GetManifestResourceStream(nom)!;
        using var lecteur = new StreamReader(flux);

        var ensemble = new HashSet<string>(StringComparer.Ordinal);
        while (lecteur.ReadLine() is { } ligne)
        {
            if (ligne.Length > 0)
            {
                ensemble.Add(ligne.Trim());
            }
        }

        return ensemble;
    }
}
