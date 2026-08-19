namespace PartyPlan.Api.Setup;

using System.Globalization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

/// <summary>
/// Limites de débit, paramétrables.
/// <para>
/// Configurables et non figées dans le code : les valeurs justes dépendent du trafic
/// réel, et les tests d'intégration partagent une seule adresse IP — ils épuiseraient
/// une limite pensée pour un utilisateur unique et échoueraient les uns à cause des
/// autres.
/// </para>
/// </summary>
public sealed class RateLimitOptions
{
    public const string SectionName = "RateLimiting";

    /// <summary>Désactivation complète, réservée aux tests automatisés.</summary>
    public bool Enabled { get; set; } = true;

    /// <summary>Requêtes par minute, toutes routes confondues.</summary>
    public int GlobalPerMinute { get; set; } = 300;

    /// <summary>Résolutions de code court par minute (RG-INV-03).</summary>
    public int ShortCodePerMinute { get; set; } = 10;

    /// <summary>Demandes de réinitialisation par heure et par adresse IP (RG-AUTH-05).</summary>
    public int PasswordResetPerHour { get; set; } = 10;

    /// <summary>Tentatives d'authentification par minute.</summary>
    public int AuthAttemptsPerMinute { get; set; } = 20;
}

/// <summary>
/// Limitation de débit (NF-SEC-04). Deux politiques nommées correspondent à des règles
/// du cahier des charges et sont appliquées explicitement par les endpoints concernés.
/// </summary>
public static class RateLimitingSetup
{
    /// <summary>Résolution d'un code court : RG-INV-03, dix par minute et par adresse.</summary>
    public const string ShortCodePolicy = "short-code";

    /// <summary>
    /// Demandes de réinitialisation de mot de passe. RG-AUTH-05 exige cinq par heure et
    /// par <b>adresse</b> : cette limite-ci porte sur l'adresse IP, et complète le
    /// décompte par adresse tenu dans le service. Les deux sont nécessaires — la limite
    /// par IP arrête un balayage d'adresses, la limite par adresse arrête le harcèlement
    /// d'un compte précis depuis plusieurs sources.
    /// </summary>
    public const string PasswordResetPolicy = "password-reset";

    /// <summary>
    /// Tentatives d'authentification et consommation de jetons. Plus permissive : une
    /// personne qui se trompe de mot de passe, ou qui recopie mal un code reçu par
    /// courriel, ne doit pas être bloquée pour une heure.
    /// </summary>
    public const string AuthAttemptPolicy = "auth-attempt";

    public static IServiceCollection AddPartyPlanRateLimiting(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        var limites = configuration.GetSection(RateLimitOptions.SectionName)
            .Get<RateLimitOptions>() ?? new RateLimitOptions();

        services.AddRateLimiter(options =>
        {
            options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

            options.OnRejected = (context, cancellationToken) =>
            {
                if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
                {
                    context.HttpContext.Response.Headers.RetryAfter =
                        ((int)retryAfter.TotalSeconds).ToString(CultureInfo.InvariantCulture);
                }

                return ValueTask.CompletedTask;
            };

            if (!limites.Enabled)
            {
                // Aucune politique n'est déclarée : `RequireRateLimiting` sur un nom
                // inconnu lèverait au démarrage, aussi les politiques restent déclarées
                // ci-dessous avec des limites inatteignables.
                DeclarerPolitiques(options, int.MaxValue, int.MaxValue, int.MaxValue);
                return;
            }

            // Garde générale : protège l'instance sans gêner un usage normal.
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    ClientKey(context),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = limites.GlobalPerMinute,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0,
                    }));

            DeclarerPolitiques(
                options,
                limites.ShortCodePerMinute,
                limites.PasswordResetPerHour,
                limites.AuthAttemptsPerMinute);
        });

        return services;
    }

    private static void DeclarerPolitiques(
        Microsoft.AspNetCore.RateLimiting.RateLimiterOptions options,
        int codeCourtParMinute,
        int reinitialisationsParHeure,
        int tentativesParMinute)
    {
        options.AddPolicy(ShortCodePolicy, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                ClientKey(context),
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = codeCourtParMinute,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                }));

        options.AddPolicy(PasswordResetPolicy, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                ClientKey(context),
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = reinitialisationsParHeure,
                    Window = TimeSpan.FromHours(1),
                    QueueLimit = 0,
                }));

        options.AddPolicy(AuthAttemptPolicy, context =>
            RateLimitPartition.GetFixedWindowLimiter(
                ClientKey(context),
                _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = tentativesParMinute,
                    Window = TimeSpan.FromMinutes(1),
                    QueueLimit = 0,
                }));
    }

    /// <summary>
    /// Partition par utilisateur si connu, sinon par adresse. Derrière un reverse proxy,
    /// l'adresse réelle vient de l'en-tête transmis : voir la configuration des
    /// en-têtes de transfert dans Program.
    /// </summary>
    private static string ClientKey(HttpContext context) =>
        context.User.Identity?.IsAuthenticated == true
            ? $"u:{context.User.Identity.Name ?? context.User.FindFirst("sub")?.Value}"
            : $"ip:{context.Connection.RemoteIpAddress}";
}
