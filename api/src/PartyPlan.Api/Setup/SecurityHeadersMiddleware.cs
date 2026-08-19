namespace PartyPlan.Api.Setup;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;

/// <summary>
/// En-têtes de sécurité appliqués à toute réponse de l'API. <c>X-Robots-Tag</c> est
/// présent y compris ici : une réponse d'API ne doit pas davantage être indexée
/// qu'une page d'événement (RG-EVT-01).
/// </summary>
public sealed class SecurityHeadersMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        var headers = context.Response.Headers;
        headers["X-Content-Type-Options"] = "nosniff";
        headers["X-Robots-Tag"] = "noindex, nofollow";
        headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
        headers["Cross-Origin-Resource-Policy"] = "same-site";
        headers.Remove("Server");

        await next(context).ConfigureAwait(false);
    }
}

public static class SecurityHeadersMiddlewareExtensions
{
    public static IApplicationBuilder UseSecurityHeaders(this IApplicationBuilder app)
    {
        ArgumentNullException.ThrowIfNull(app);

        return app.UseMiddleware<SecurityHeadersMiddleware>();
    }
}
