namespace PartyPlan.Modules.Events.Application;

using System.Security.Cryptography;

/// <summary>
/// Jeton du lien d'invitation (RG-INV-01).
/// <para>
/// Le lien est la seule protection d'un événement privé partagé par messagerie : le
/// jeton doit donc être imprévisible, et non déductible de l'identifiant de l'événement.
/// </para>
/// </summary>
public static class InviteToken
{
    private const int Bytes = 24;

    /// <summary>Entropie du jeton, en bits.</summary>
    public const int EntropyBits = Bytes * 8;

    /// <summary>
    /// Génère un jeton encodé en base64url. Cette variante évite <c>+</c>, <c>/</c> et
    /// <c>=</c>, qui seraient réencodés lors du partage du lien et le rendraient invalide
    /// au collage.
    /// </summary>
    public static string Generate() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(Bytes))
            .Replace('+', '-')
            .Replace('/', '_')
            .TrimEnd('=');
}
