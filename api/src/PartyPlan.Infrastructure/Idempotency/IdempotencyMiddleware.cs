namespace PartyPlan.Infrastructure.Idempotency;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Idempotence des créations (§8.1).
/// <para>
/// Intergiciel et non filtre d'endpoint : un filtre s'exécute <b>après</b> le liage des
/// arguments, donc après consommation du corps de la requête. L'empreinte serait alors
/// calculée sur une chaîne vide, et deux requêtes différentes porteraient la même
/// empreinte — exactement le cas que l'idempotence doit distinguer.
/// </para>
/// <para>
/// Placé après le routage et l'autorisation : il lui faut les métadonnées de l'endpoint
/// et l'identité de l'appelant.
/// </para>
/// </summary>
public sealed class IdempotencyMiddleware(RequestDelegate next, ILogger<IdempotencyMiddleware> logger)
{
    public const string HeaderName = "Idempotency-Key";

    public const string ReplayedHeaderName = "Idempotency-Replayed";

    /// <summary>
    /// Durée de conservation d'une trace. Vingt-quatre heures couvrent la réémission
    /// d'un client resté hors ligne, sans faire croître la table indéfiniment.
    /// </summary>
    public static readonly TimeSpan Retention = TimeSpan.FromHours(24);

    /// <summary>
    /// Mêmes conventions que la sérialisation de l'hôte. Les options par défaut de
    /// <c>JsonSerializer</c> produisent du PascalCase alors que l'hôte émet du camelCase :
    /// une réponse rejouée aurait des noms de propriétés différents de l'originale, et le
    /// client casserait au moment précis où l'idempotence est censée le protéger.
    /// </summary>
    private static readonly System.Text.Json.JsonSerializerOptions ResponseFormat =
        new(System.Text.Json.JsonSerializerDefaults.Web);

    public async Task InvokeAsync(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        if (context.GetEndpoint()?.Metadata.GetMetadata<IdempotencyRequirement>() is null)
        {
            await next(context).ConfigureAwait(false);
            return;
        }

        var cle = context.Request.Headers[HeaderName].FirstOrDefault();

        if (!IdempotencyFingerprint.IsValidKey(cle))
        {
            await EcrireProblemeAsync(
                context,
                StatusCodes.Status400BadRequest,
                $"L'en-tête {HeaderName} est obligatoire sur cette opération.",
                "idempotency.key_required").ConfigureAwait(false);
            return;
        }

        var empreinte = IdempotencyFingerprint.Compute(await LireCorpsAsync(context).ConfigureAwait(false));
        var endpoint = $"{context.Request.Method} {context.Request.Path}";

        var db = context.RequestServices.GetRequiredService<PartyPlanDbContext>();
        var currentUser = context.RequestServices.GetRequiredService<ICurrentUser>();
        var clock = context.RequestServices.GetRequiredService<IClock>();
        var ids = context.RequestServices.GetRequiredService<IIdGenerator>();

        var maintenant = clock.UtcNow;
        var utilisateur = currentUser.UserId;

        var existant = await db.IdempotencyRecords
            .FirstOrDefaultAsync(
                r => r.Key == cle
                     && r.UserId == utilisateur
                     && r.Endpoint == endpoint
                     && r.ExpiresAt > maintenant,
                context.RequestAborted)
            .ConfigureAwait(false);

        if (existant is not null)
        {
            if (existant.RequestHash != empreinte)
            {
                logger.LogWarning(
                    "Clé d'idempotence réutilisée avec un corps différent sur {Endpoint}",
                    endpoint);

                await EcrireProblemeAsync(
                    context,
                    StatusCodes.Status409Conflict,
                    "Cette clé a déjà servi pour une autre requête.",
                    "idempotency.key_reused").ConfigureAwait(false);
                return;
            }

            // Réémission : la réponse d'origine est rejouée. Réexécuter l'opération
            // créerait le doublon que l'on cherche à éviter.
            logger.LogInformation("Réémission détectée sur {Endpoint}, réponse rejouée", endpoint);

            context.Response.StatusCode = existant.StatusCode;
            context.Response.Headers[ReplayedHeaderName] = "true";

            if (existant.ResponseBody is not null)
            {
                context.Response.ContentType = "application/json; charset=utf-8";
                await context.Response.WriteAsync(existant.ResponseBody, context.RequestAborted)
                    .ConfigureAwait(false);
            }

            return;
        }

        // Le flux de réponse est détourné vers un tampon, afin de pouvoir mémoriser le
        // corps sans priver le client de sa réponse.
        var fluxOrigine = context.Response.Body;
        using var tampon = new MemoryStream();
        context.Response.Body = tampon;

        try
        {
            await next(context).ConfigureAwait(false);
        }
        finally
        {
            context.Response.Body = fluxOrigine;
        }

        tampon.Position = 0;
        var corpsReponse = await new StreamReader(tampon).ReadToEndAsync(context.RequestAborted)
            .ConfigureAwait(false);

        tampon.Position = 0;
        await tampon.CopyToAsync(fluxOrigine, context.RequestAborted).ConfigureAwait(false);

        // Seules les réussites sont mémorisées : rejouer un échec empêcherait de corriger
        // une requête invalide et de la renvoyer avec la même clé, ce que fait
        // naturellement un client après un message d'erreur.
        if (context.Response.StatusCode is < 200 or >= 300)
        {
            return;
        }

        db.IdempotencyRecords.Add(new IdempotencyRecord
        {
            Id = ids.NewId(),
            Key = cle!,
            UserId = utilisateur,
            Endpoint = endpoint,
            RequestHash = empreinte,
            StatusCode = context.Response.StatusCode,
            ResponseBody = string.IsNullOrEmpty(corpsReponse) ? null : corpsReponse,
            CreatedAt = maintenant,
            ExpiresAt = maintenant.Add(Retention),
        });

        await db.SaveChangesAsync(context.RequestAborted).ConfigureAwait(false);
    }

    /// <summary>
    /// Lit le corps sans le consommer pour la suite du traitement. La mise en tampon est
    /// indispensable : le flux de requête n'est lisible qu'une fois.
    /// </summary>
    private static async Task<string> LireCorpsAsync(HttpContext context)
    {
        context.Request.EnableBuffering();

        using var lecteur = new StreamReader(
            context.Request.Body,
            System.Text.Encoding.UTF8,
            detectEncodingFromByteOrderMarks: false,
            leaveOpen: true);

        var corps = await lecteur.ReadToEndAsync(context.RequestAborted).ConfigureAwait(false);
        context.Request.Body.Position = 0;

        return corps;
    }

    private static Task EcrireProblemeAsync(
        HttpContext context,
        int statut,
        string titre,
        string code)
    {
        context.Response.StatusCode = statut;

        return context.Response.WriteAsJsonAsync(
            new
            {
                type = $"https://partyplan.maxencecoeur.fr/errors/{code}",
                title = titre,
                status = statut,
                code,
            },
            ResponseFormat,
            context.RequestAborted);
    }
}

public static class IdempotencyMiddlewareExtensions
{
    public static IApplicationBuilder UseIdempotency(this IApplicationBuilder app)
    {
        ArgumentNullException.ThrowIfNull(app);

        return app.UseMiddleware<IdempotencyMiddleware>();
    }
}
