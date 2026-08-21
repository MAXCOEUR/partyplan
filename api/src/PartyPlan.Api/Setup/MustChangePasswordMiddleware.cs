namespace PartyPlan.Api.Setup;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using PartyPlan.Infrastructure.Identity;

/// <summary>
/// Bloque toute action tant que le mot de passe n'a pas été changé (RG-ADM-10).
/// <para>
/// Le compte administrateur amorcé porte un mot de passe inscrit dans un fichier de
/// configuration, donc lisible par quiconque accède au serveur. Le laisser agir avant
/// changement reviendrait à ne pas avoir posé la contrainte.
/// </para>
/// <para>
/// Quatre chemins restent ouverts, sans quoi la contrainte serait un cul-de-sac : lire
/// son profil, changer son mot de passe, renouveler son jeton, se déconnecter.
/// </para>
/// </summary>
public sealed class MustChangePasswordMiddleware(RequestDelegate next)
{
    private static readonly string[] CheminsAutorises =
    [
        "/v1/auth/password/change",
        // Le renouvellement du jeton doit rester ouvert : les revendications sont
        // figées à l'émission, et le jeton en main porte encore l'obligation après le
        // changement. Sans cette ouverture, le refus survivrait à la correction qu'il
        // exige, pendant toute la durée de vie du jeton. Aucun contournement pour
        // autant : le jeton renouvelé reprend l'état du compte en base, obligation
        // comprise tant qu'elle subsiste.
        "/v1/auth/refresh",
        "/v1/auth/logout",
        "/v1/me",
        "/health/live",
        "/health/ready",
    ];

    public async Task InvokeAsync(HttpContext context)
    {
        ArgumentNullException.ThrowIfNull(context);

        var doitChanger = context.User.HasClaim(PartyPlanClaims.MustChangePassword, "true");

        if (!doitChanger || EstAutorise(context.Request))
        {
            await next(context).ConfigureAwait(false);
            return;
        }

        context.Response.StatusCode = StatusCodes.Status403Forbidden;

        await context.Response.WriteAsJsonAsync(
            new
            {
                type = "https://partyplan.maxencecoeur.fr/errors/must-change-password",
                title = "Change ton mot de passe avant de continuer.",
                status = StatusCodes.Status403Forbidden,
                code = "auth.must_change_password",
            },
            context.RequestAborted).ConfigureAwait(false);
    }

    private static bool EstAutorise(HttpRequest requete)
    {
        var chemin = requete.Path.Value ?? string.Empty;

        // La lecture du profil est autorisée, sa modification non : l'interface doit
        // pouvoir afficher qui est connecté pour présenter le formulaire.
        if (chemin.Equals("/v1/me", StringComparison.OrdinalIgnoreCase))
        {
            return HttpMethods.IsGet(requete.Method);
        }

        return CheminsAutorises.Any(
            autorise => chemin.Equals(autorise, StringComparison.OrdinalIgnoreCase));
    }
}

public static class MustChangePasswordMiddlewareExtensions
{
    public static IApplicationBuilder UseMustChangePassword(this IApplicationBuilder app)
    {
        ArgumentNullException.ThrowIfNull(app);

        return app.UseMiddleware<MustChangePasswordMiddleware>();
    }
}
