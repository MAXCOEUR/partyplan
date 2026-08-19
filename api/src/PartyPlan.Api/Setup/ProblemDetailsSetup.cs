namespace PartyPlan.Api.Setup;

using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using PartyPlan.Infrastructure.Http;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Réponses d'erreur au format RFC 9457 (§8.1). Une seule traduction
/// <see cref="ErrorKind"/> → statut HTTP, ici et nulle part ailleurs.
/// </summary>
public static class ProblemDetailsSetup
{
    public static int ToStatusCode(ErrorKind kind) => kind switch
    {
        ErrorKind.Validation => StatusCodes.Status400BadRequest,
        ErrorKind.Unauthenticated => StatusCodes.Status401Unauthorized,
        ErrorKind.Forbidden => StatusCodes.Status403Forbidden,
        ErrorKind.NotFound => StatusCodes.Status404NotFound,
        ErrorKind.Conflict => StatusCodes.Status409Conflict,
        ErrorKind.RuleViolation => StatusCodes.Status422UnprocessableEntity,
        _ => StatusCodes.Status500InternalServerError,
    };

    public static IServiceCollection AddPartyPlanProblemDetails(this IServiceCollection services)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddProblemDetails(options =>
            options.CustomizeProblemDetails = context =>
            {
                // L'identifiant de corrélation est renvoyé au client : c'est ce qu'un
                // utilisateur peut communiquer au support (NF-OPS-02).
                var correlationId = context.HttpContext.Response
                    .Headers[CorrelationIdMiddleware.HeaderName]
                    .FirstOrDefault();

                if (!string.IsNullOrEmpty(correlationId))
                {
                    context.ProblemDetails.Extensions["correlationId"] = correlationId;
                }

                context.ProblemDetails.Instance ??= context.HttpContext.Request.Path;
            });

        services.AddExceptionHandler<UnhandledExceptionHandler>();

        return services;
    }
}

/// <summary>
/// Dernier filet. Aucune exception ne doit fuir vers le client : ni message interne,
/// ni pile d'appels (NF-SEC-03).
/// </summary>
internal sealed class UnhandledExceptionHandler(ILogger<UnhandledExceptionHandler> logger) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        logger.LogError(exception, "Exception non gérée sur {Method} {Path}",
            httpContext.Request.Method, httpContext.Request.Path);

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;

        await httpContext.Response.WriteAsJsonAsync(
            new ProblemDetails
            {
                Status = StatusCodes.Status500InternalServerError,
                Title = "Une erreur inattendue est survenue.",
                Type = "https://partyplan.maxencecoeur.fr/errors/unexpected",
                Instance = httpContext.Request.Path,
                Extensions =
                {
                    ["correlationId"] = httpContext.Response
                        .Headers[CorrelationIdMiddleware.HeaderName]
                        .FirstOrDefault() ?? httpContext.TraceIdentifier,
                },
            },
            cancellationToken).ConfigureAwait(false);

        return true;
    }
}
