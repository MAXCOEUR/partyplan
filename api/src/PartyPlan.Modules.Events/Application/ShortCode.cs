namespace PartyPlan.Modules.Events.Application;

using System.Globalization;
using System.Security.Cryptography;

/// <summary>
/// Code court d'un événement, au format <c>PLAN-XXXXXX</c> (RG-INV-02).
/// <para>
/// Six positions et non quatre : quatre caractères ne donnent qu'environ un million de
/// combinaisons, énumérables en quelques heures. Six en donnent un milliard, ce qui
/// combiné à la limitation de débit du RG-INV-03 rend la recherche exhaustive vaine.
/// </para>
/// </summary>
public static class ShortCode
{
    public const string Prefix = "PLAN-";

    public const int Length = 6;

    /// <summary>
    /// Alphabet de trente-deux caractères, sans <c>I</c>, <c>O</c>, <c>0</c> ni
    /// <c>1</c> : un code se dicte au téléphone et se recopie à la main, où ces
    /// caractères sont indiscernables.
    /// </summary>
    public const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    /// <summary>Nombre de combinaisons possibles.</summary>
    public static long Combinations { get; } = (long)Math.Pow(Alphabet.Length, Length);

    public static string Generate()
    {
        var caracteres = new char[Length];

        for (var i = 0; i < Length; i++)
        {
            caracteres[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
        }

        return Prefix + new string(caracteres);
    }

    /// <summary>
    /// Normalise une saisie. Le préfixe, la casse, les espaces et les tirets sont
    /// tolérés : refuser « plan abc234 » ferait échouer l'entrée pour une raison que
    /// l'utilisateur ne comprendrait pas.
    /// </summary>
    public static bool TryNormalize(string? input, out string normalized)
    {
        normalized = string.Empty;

        if (string.IsNullOrWhiteSpace(input))
        {
            return false;
        }

        var brut = input
            .Replace(" ", string.Empty, StringComparison.Ordinal)
            .Replace("-", string.Empty, StringComparison.Ordinal)
            .ToUpper(CultureInfo.InvariantCulture);

        if (brut.StartsWith("PLAN", StringComparison.Ordinal))
        {
            brut = brut["PLAN".Length..];
        }

        if (brut.Length != Length || !brut.All(Alphabet.Contains))
        {
            return false;
        }

        normalized = Prefix + brut;

        return true;
    }
}
