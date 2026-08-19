namespace PartyPlan.Infrastructure.Http;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using PartyPlan.Infrastructure.Persistence;

/// <summary>
/// Établit le périmètre d'événements avant l'exécution de l'endpoint. Placé après
/// l'authentification : sans identité, le périmètre serait systématiquement vide.
/// </summary>
public sealed class EventScopeMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, EventScopePrimer primer)
    {
        ArgumentNullException.ThrowIfNull(context);
        ArgumentNullException.ThrowIfNull(primer);

        await primer.PrimeAsync(context.RequestAborted).ConfigureAwait(false);
        await next(context).ConfigureAwait(false);
    }
}

public static class EventScopeMiddlewareExtensions
{
    public static IApplicationBuilder UseEventScope(this IApplicationBuilder app)
    {
        ArgumentNullException.ThrowIfNull(app);

        return app.UseMiddleware<EventScopeMiddleware>();
    }
}
