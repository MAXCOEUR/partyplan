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
/// Huit caractères au minimum, trente au maximum, les quatre classes de caractères
/// exigées, et refus des mots de passe divulgués.
/// </para>
/// <para>
/// <b>Changée le 25/08/2026</b>, sur décision explicite du produit. La règle
/// précédente — douze caractères, aucune exigence de composition — suivait les
/// recommandations de l'ANSSI et de la CNIL. Ce que la nouvelle coûte, pour mémoire :
/// huit caractères complexes offrent moins de résistance que douze quelconques, et le
/// plafond à trente interdit les phrases de passe, qui sont la défense la plus solide.
/// Le refus des mots de passe divulgués reste donc la protection la plus efficace de
/// cette politique, et c'est lui qu'il faut garder si l'on retouche le reste.
/// </para>
/// </summary>
public sealed class PasswordPolicy : IPasswordPolicy
{
    public const int MinLength = 8;

    /// <summary>
    /// Plafond. Sert d'abord à borner le coût d'Argon2id : sur une entrée de plusieurs
    /// mégaoctets, le hachage devient un vecteur de déni de service.
    /// </summary>
    public const int MaxLength = 30;

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

    public static readonly DomainError MissingComplexity = DomainError.Validation(
        "password.missing_complexity",
        "Le mot de passe doit contenir au moins une majuscule, une minuscule, "
            + "un chiffre et un caractère spécial.");

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

        // La divulgation passe avant la composition, et l'ordre compte. Dire « ajoute un
        // caractère spécial » à quelqu'un dont le mot de passe figure dans une fuite le
        // pousse vers une variante de ce même mot de passe, que les attaquants essaient
        // en premier. Le fait important est qu'il est connu.
        if (IsCompromised(password))
        {
            return Compromised;
        }

        return EstComplet(password) ? Result.Success() : MissingComplexity;
    }

    /// <summary>
    /// Vrai si les quatre classes de caractères sont présentes.
    /// <para>
    /// « Spécial » se définit par exclusion — ni lettre, ni chiffre — plutôt que par une
    /// liste. Une liste fermée refuserait un caractère légitime que personne n'aurait
    /// prévu, un tiret cadratin ou une lettre accentuée par exemple, et l'erreur serait
    /// incompréhensible pour qui la reçoit.
    /// </para>
    /// </summary>
    private static bool EstComplet(string password)
    {
        var majuscule = false;
        var minuscule = false;
        var chiffre = false;
        var special = false;

        foreach (var c in password)
        {
            if (char.IsUpper(c))
            {
                majuscule = true;
            }
            else if (char.IsLower(c))
            {
                minuscule = true;
            }
            else if (char.IsDigit(c))
            {
                chiffre = true;
            }
            else
            {
                special = true;
            }
        }

        return majuscule && minuscule && chiffre && special;
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
