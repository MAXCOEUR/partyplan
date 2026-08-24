namespace PartyPlan.Modules.Users.Endpoints;

using System.Security.Claims;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Users.Application;
using PartyPlan.Modules.Users.Contracts;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Endpoints d'authentification (§8.2).</summary>
internal static class AuthEndpoints
{
    // Noms des politiques de limitation de débit. Déclarés en constantes plutôt
    // qu'importés de l'hôte : un module ne dépend pas de l'hôte.
    private const string PasswordResetPolicy = "password-reset";

    private const string AuthAttemptPolicy = "auth-attempt";

    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/auth").WithTags("Auth");

        groupe.MapPost("/register", async (
                RegisterRequest corps,
                AuthenticationService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var resultat = await service.RegisterAsync(
                    corps.Email,
                    corps.Password,
                    corps.DisplayName,
                    http.Request.Headers.UserAgent.ToString(),
                    http.Connection.RemoteIpAddress,
                    cancellationToken).ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("Register")
            .WithSummary("Crée un compte et ouvre une session.")
            .RequireRateLimiting(AuthAttemptPolicy)
            .Produces<TokenResponse>()
            .ProducesValidationProblem();

        groupe.MapPost("/login", async (
                LoginRequest corps,
                AuthenticationService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var resultat = await service.LoginAsync(
                    corps.Email,
                    corps.Password,
                    http.Request.Headers.UserAgent.ToString(),
                    http.Connection.RemoteIpAddress,
                    cancellationToken).ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("Login")
            .WithSummary("Ouvre une session.")
            .Produces<TokenResponse>()
            .ProducesValidationProblem();

        // --- Connexions tierces (EF-AUTH-06, EF-AUTH-08) ---

        groupe.MapPost("/google", async (
                ExternalSignInRequest corps,
                ExternalSignInService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var resultat = await service.SignInAsync(
                    ExternalProviders.Google,
                    corps.IdToken,
                    http.Request.Headers.UserAgent.ToString(),
                    http.Connection.RemoteIpAddress,
                    cancellationToken).ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("SignInWithGoogle")
            .WithSummary("Connexion Google. Sans clé configurée, renvoie une erreur explicite.")
            .RequireRateLimiting(AuthAttemptPolicy)
            .Produces<TokenResponse>();

        groupe.MapGet("/providers", async (
                ExternalSignInService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = UserId(http.User);

                return utilisateur is null
                    ? Results.Unauthorized()
                    : Respond(await service
                        .GetMethodsAsync(utilisateur.Value, cancellationToken)
                        .ConfigureAwait(false));
            })
            .WithName("ListSignInMethods")
            .WithSummary("Moyens de connexion du compte courant, et fournisseurs disponibles.")
            .RequireAuthorization()
            .Produces<SignInMethods>();

        groupe.MapPost("/providers/{provider}/link", async (
                string provider,
                ExternalSignInRequest corps,
                ExternalSignInService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = UserId(http.User);

                return utilisateur is null
                    ? Results.Unauthorized()
                    : Respond(await service
                        .LinkAsync(utilisateur.Value, provider, corps.IdToken, cancellationToken)
                        .ConfigureAwait(false));
            })
            .WithName("LinkProvider")
            .WithSummary("Rattache une connexion tierce au compte courant.")
            .RequireAuthorization();

        groupe.MapDelete("/providers/{provider}", async (
                string provider,
                ExternalSignInService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = UserId(http.User);

                return utilisateur is null
                    ? Results.Unauthorized()
                    : Respond(await service
                        .UnlinkAsync(utilisateur.Value, provider, cancellationToken)
                        .ConfigureAwait(false));
            })
            .WithName("UnlinkProvider")
            .WithSummary("Détache une connexion tierce. Refusé si c'est le dernier accès.")
            .RequireAuthorization();

        groupe.MapPost("/refresh", async (
                RefreshRequest corps,
                AuthenticationService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var resultat = await service.RefreshAsync(
                    corps.RefreshToken,
                    http.Connection.RemoteIpAddress,
                    cancellationToken).ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("Refresh")
            .WithSummary("Renouvelle la session. Le jeton présenté est invalidé.")
            .Produces<TokenResponse>();

        groupe.MapPost("/logout", async (
                AuthenticationService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var session = SessionId(http.User);

                if (session is null)
                {
                    return Results.NoContent();
                }

                await service.LogoutAsync(session.Value, cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("Logout")
            .WithSummary("Révoque la session courante.")
            .RequireAuthorization();

        // --- Mot de passe ---

        groupe.MapPost("/password/forgot", async (
                ForgotPasswordRequest corps,
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                await service.RequestPasswordResetAsync(
                    corps.Email,
                    http.Connection.RemoteIpAddress,
                    requestedByAdmin: false,
                    cancellationToken).ConfigureAwait(false);

                // RG-AUTH-04 : réponse identique que l'adresse existe ou non. Elle est
                // donc renvoyée sans consulter le résultat de l'opération.
                return Results.Accepted();
            })
            .WithName("ForgotPassword")
            .WithSummary("Envoie un code de réinitialisation. Réponse identique si l'adresse est inconnue.")
            .RequireRateLimiting(PasswordResetPolicy);

        groupe.MapPost("/password/reset", async (
                ResetPasswordRequest corps,
                AccountService service,
                CancellationToken cancellationToken) =>
            {
                var resultat = await service.ResetPasswordAsync(
                    corps.Token,
                    corps.NewPassword,
                    cancellationToken).ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("ResetPassword")
            .WithSummary("Définit un nouveau mot de passe et révoque toutes les sessions.")
            .RequireRateLimiting(AuthAttemptPolicy);

        groupe.MapPost("/password/change", async (
                ChangePasswordRequest corps,
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                var resultat = await service.ChangePasswordAsync(
                    utilisateur.Value,
                    corps.CurrentPassword,
                    corps.NewPassword,
                    SessionId(http.User),
                    cancellationToken).ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("ChangePassword")
            .WithSummary("Change le mot de passe et révoque les autres sessions.")
            .RequireAuthorization();

        // --- Adresse ---

        groupe.MapPost("/email/verify", async (
                VerifyEmailRequest corps,
                AccountService service,
                CancellationToken cancellationToken) =>
            {
                var resultat = await service.ConfirmEmailAsync(corps.Token, cancellationToken)
                    .ConfigureAwait(false);

                return Respond(resultat);
            })
            .WithName("VerifyEmail")
            .WithSummary("Confirme une adresse à partir du code reçu.")
            .RequireRateLimiting(AuthAttemptPolicy);
    }

    internal static Guid? UserId(ClaimsPrincipal principal) =>
        Guid.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : null;

    internal static Guid? SessionId(ClaimsPrincipal principal) =>
        Guid.TryParse(principal.FindFirstValue("pp:session"), out var id) ? id : null;

    /// <summary>Traduction unique d'un résultat en réponse HTTP (§8.3).</summary>
    internal static IResult Respond<T>(Result<T> resultat) =>
        resultat.IsSuccess
            ? Results.Ok(resultat.Value)
            : Problem(resultat.Error!);

    internal static IResult Respond(Result resultat) =>
        resultat.IsSuccess
            ? Results.NoContent()
            : Problem(resultat.Error!);

    internal static IResult Problem(DomainError erreur) => Results.Problem(
        title: erreur.Message,
        statusCode: erreur.Kind switch
        {
            ErrorKind.Validation => StatusCodes.Status400BadRequest,
            ErrorKind.Unauthenticated => StatusCodes.Status401Unauthorized,
            ErrorKind.Forbidden => StatusCodes.Status403Forbidden,
            ErrorKind.NotFound => StatusCodes.Status404NotFound,
            ErrorKind.Conflict => StatusCodes.Status409Conflict,
            ErrorKind.RuleViolation => StatusCodes.Status422UnprocessableEntity,
            _ => StatusCodes.Status500InternalServerError,
        },
        extensions: new Dictionary<string, object?> { ["code"] = erreur.Code });
}
