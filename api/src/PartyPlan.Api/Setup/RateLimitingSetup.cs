namespace PartyPlan.Api.Setup;

using System.Globalization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;

/// <summary>
/// Limitation de débit (NF-SEC-04). Deux politiques nommées correspondent à des règles
/// du cahier des charges et sont appliquées explicitement par les endpoints concernés.
/// </summary>
public static class RateLimitingSetup
{
    /// <summary>Résolution d'un code court : RG-INV-03, dix par minute et par adresse.</summary>
    public const string ShortCodePolicy = "short-code";

    /// <summary>Endpoints d'authentification : RG-AUTH-05, cinq par heure et par adresse.</summary>
    public const string AuthPolicy = "auth";

    public static IServiceCollection AddPartyPlanRateLimiting(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

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

            // Garde générale : protège l'instance sans gêner un usage normal.
            options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    ClientKey(context),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 300,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0,
                    }));

            options.AddPolicy(ShortCodePolicy, context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    ClientKey(context),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 10,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0,
                    }));

            options.AddPolicy(AuthPolicy, context =>
                RateLimitPartition.GetFixedWindowLimiter(
                    ClientKey(context),
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 5,
                        Window = TimeSpan.FromHours(1),
                        QueueLimit = 0,
                    }));
        });

        return services;
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
