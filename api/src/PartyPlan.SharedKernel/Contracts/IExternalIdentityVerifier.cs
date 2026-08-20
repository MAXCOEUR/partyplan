namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Vérification d'un jeton d'identité émis par un fournisseur tiers.
/// <para>
/// Le client obtient le jeton auprès de Google puis le présente à l'API, qui en vérifie
/// la signature. Ne jamais faire confiance au jeton sans cette vérification : un jeton
/// forgé donnerait accès à n'importe quel compte.
/// </para>
/// </summary>
public interface IExternalIdentityVerifier
{
    /// <summary>Vrai lorsque le fournisseur est configuré. Faux en développement sans clé.</summary>
    bool IsConfigured(string provider);

    Task<Result<ExternalIdentity>> VerifyAsync(
        string provider,
        string idToken,
        CancellationToken cancellationToken);
}

/// <summary>
/// Identité attestée par un fournisseur tiers.
/// </summary>
/// <param name="Subject">
/// Identifiant stable chez le fournisseur. C'est la seule clé de rattachement fiable :
/// une adresse e-mail change, ce sujet non.
/// </param>
/// <param name="Email">Adresse déclarée, éventuellement absente.</param>
/// <param name="EmailVerified">
/// Vrai si le fournisseur atteste avoir vérifié l'adresse. Déterminant : rattacher un
/// compte existant sur une adresse non vérifiée permettrait une usurpation.
/// </param>
/// <param name="DisplayName">Nom affiché proposé par le fournisseur.</param>
public sealed record ExternalIdentity(
    string Subject,
    string? Email,
    bool EmailVerified,
    string? DisplayName);

/// <summary>Noms des fournisseurs pris en charge.</summary>
public static class ExternalProviders
{
    public const string Google = "google";
    public const string Apple = "apple";
}
