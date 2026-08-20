namespace PartyPlan.Infrastructure.Identity;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

public sealed class GoogleOptions
{
    public const string SectionName = "Google";

    /// <summary>
    /// Identifiants clients acceptés. Trois sont nécessaires — Web, Android, iOS — car
    /// Google émet un jeton par plateforme et l'audience diffère à chaque fois.
    /// </summary>
    public string? ClientId { get; set; }

    public string? AndroidClientId { get; set; }

    public string? IosClientId { get; set; }

    public IReadOnlyList<string> Audiences =>
    [
        .. new[] { ClientId, AndroidClientId, IosClientId }
            .Where(c => !string.IsNullOrWhiteSpace(c))
            .Select(c => c!),
    ];
}

/// <summary>
/// Vérifie un jeton d'identité Google.
/// <para>
/// Les clés publiques sont récupérées auprès de Google et mises en cache : Google les
/// fait tourner régulièrement, les figer dans la configuration casserait la connexion
/// sans avertissement.
/// </para>
/// <para>
/// Sans identifiant client configuré, la vérification échoue proprement plutôt que de
/// laisser passer : le développement se fait alors par mot de passe (NF-DEV-05).
/// </para>
/// </summary>
public sealed class GoogleIdentityVerifier(
    IOptions<GoogleOptions> options,
    IHttpClientFactory clients,
    ILogger<GoogleIdentityVerifier> logger) : IExternalIdentityVerifier
{
    private const string CertsUrl = "https://www.googleapis.com/oauth2/v3/certs";

    /// <summary>Émetteurs acceptés. Google en publie deux formes, historiquement.</summary>
    private static readonly string[] Issuers =
    [
        "https://accounts.google.com",
        "accounts.google.com",
    ];

    /// <summary>
    /// Durée de cache des clés. Une heure : suffisant pour éviter un appel par connexion,
    /// assez court pour suivre une rotation.
    /// </summary>
    private static readonly TimeSpan KeyCacheDuration = TimeSpan.FromHours(1);

    private static readonly SemaphoreSlim Verrou = new(1, 1);

    private static JsonWebKeySet? _cles;
    private static DateTimeOffset _clesExpirent = DateTimeOffset.MinValue;

    public static readonly DomainError NotConfigured = DomainError.Rule(
        "external.not_configured",
        "La connexion avec ce service n'est pas disponible.");

    public static readonly DomainError InvalidToken = DomainError.Validation(
        "external.invalid_token",
        "Cette connexion a échoué. Réessaie, ou utilise ton mot de passe.");

    public bool IsConfigured(string provider) =>
        string.Equals(provider, ExternalProviders.Google, StringComparison.OrdinalIgnoreCase)
        && options.Value.Audiences.Count > 0;

    public async Task<Result<ExternalIdentity>> VerifyAsync(
        string provider,
        string idToken,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured(provider))
        {
            logger.LogWarning(
                "Tentative de connexion {Fournisseur} alors qu'aucun identifiant client "
                + "n'est configuré.",
                provider);

            return NotConfigured;
        }

        if (string.IsNullOrWhiteSpace(idToken))
        {
            return InvalidToken;
        }

        var cles = await ObtenirClesAsync(cancellationToken).ConfigureAwait(false);

        if (cles is null)
        {
            // Google injoignable : refuser plutôt que d'accepter sans vérifier.
            return InvalidToken;
        }

        var parametres = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuers = Issuers,
            ValidateAudience = true,
            ValidAudiences = options.Value.Audiences,
            ValidateIssuerSigningKey = true,
            IssuerSigningKeys = cles.GetSigningKeys(),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(2),
        };

        var resultat = await new JsonWebTokenHandler()
            .ValidateTokenAsync(idToken, parametres)
            .ConfigureAwait(false);

        if (!resultat.IsValid)
        {
            logger.LogWarning(
                resultat.Exception,
                "Jeton d'identité {Fournisseur} rejeté.",
                provider);

            return InvalidToken;
        }

        var sujet = Lire(resultat, "sub");

        if (string.IsNullOrWhiteSpace(sujet))
        {
            return InvalidToken;
        }

        return new ExternalIdentity(
            sujet,
            Lire(resultat, "email"),
            string.Equals(Lire(resultat, "email_verified"), "true", StringComparison.OrdinalIgnoreCase),
            Lire(resultat, "name") ?? Lire(resultat, "given_name"));
    }

    private static string? Lire(TokenValidationResult resultat, string revendication) =>
        resultat.Claims.TryGetValue(revendication, out var valeur) ? valeur?.ToString() : null;

    private async Task<JsonWebKeySet?> ObtenirClesAsync(CancellationToken cancellationToken)
    {
        if (_cles is not null && _clesExpirent > DateTimeOffset.UtcNow)
        {
            return _cles;
        }

        await Verrou.WaitAsync(cancellationToken).ConfigureAwait(false);

        try
        {
            // Deuxième contrôle sous verrou : plusieurs connexions simultanées ne doivent
            // pas déclencher plusieurs récupérations.
            if (_cles is not null && _clesExpirent > DateTimeOffset.UtcNow)
            {
                return _cles;
            }

            using var client = clients.CreateClient(nameof(GoogleIdentityVerifier));
            var json = await client.GetStringAsync(new Uri(CertsUrl), cancellationToken)
                .ConfigureAwait(false);

            _cles = new JsonWebKeySet(json);
            _clesExpirent = DateTimeOffset.UtcNow.Add(KeyCacheDuration);

            return _cles;
        }
        catch (Exception exception) when (exception is not OperationCanceledException)
        {
            logger.LogError(exception, "Récupération des clés publiques Google impossible.");

            // Les clés précédentes, même périmées, valent mieux que rien : une panne
            // réseau passagère ne doit pas empêcher toutes les connexions.
            return _cles;
        }
        finally
        {
            Verrou.Release();
        }
    }
}
