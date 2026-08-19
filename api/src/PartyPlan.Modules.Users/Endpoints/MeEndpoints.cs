namespace PartyPlan.Modules.Users.Endpoints;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Users.Application;
using PartyPlan.Modules.Users.Contracts;
using PartyPlan.SharedKernel.Contracts;

/// <summary>Endpoints du compte de l'appelant (§8.2).</summary>
internal static class MeEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/me")
            .WithTags("Me")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return AuthEndpoints.Respond(
                    await service.GetProfileAsync(utilisateur.Value, cancellationToken)
                        .ConfigureAwait(false));
            })
            .WithName("GetMe")
            .WithSummary("Profil de l'appelant.")
            .Produces<MyProfile>();

        groupe.MapPatch("/", async (
                UpdateProfileRequest corps,
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return AuthEndpoints.Respond(
                    await service.UpdateProfileAsync(
                        utilisateur.Value,
                        corps.DisplayName,
                        corps.Locale,
                        corps.Timezone,
                        cancellationToken).ConfigureAwait(false));
            })
            .WithName("UpdateMe")
            .WithSummary("Modifie le nom affiché, la langue et le fuseau horaire.")
            .Produces<MyProfile>();

        groupe.MapPost("/email", async (
                ChangeEmailRequest corps,
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return AuthEndpoints.Respond(
                    await service.RequestEmailChangeAsync(
                        utilisateur.Value,
                        corps.NewEmail,
                        http.Connection.RemoteIpAddress,
                        cancellationToken).ConfigureAwait(false));
            })
            .WithName("RequestEmailChange")
            .WithSummary("Demande un changement d'adresse. Effectif après confirmation.");

        // --- Sessions ---

        groupe.MapGet("/sessions", async (
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return Results.Ok(await service.ListSessionsAsync(
                        utilisateur.Value,
                        AuthEndpoints.SessionId(http.User),
                        cancellationToken)
                    .ConfigureAwait(false));
            })
            .WithName("ListMySessions")
            .WithSummary("Sessions actives de l'appelant.")
            .Produces<IReadOnlyList<MySession>>();

        groupe.MapDelete("/sessions/{sessionId:guid}", async (
                Guid sessionId,
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return AuthEndpoints.Respond(
                    await service.RevokeSessionAsync(utilisateur.Value, sessionId, cancellationToken)
                        .ConfigureAwait(false));
            })
            .WithName("RevokeMySession")
            .WithSummary("Révoque une session, y compris la session courante.");

        groupe.MapDelete("/sessions", async (
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                var nombre = await service.RevokeOtherSessionsAsync(
                        utilisateur.Value,
                        AuthEndpoints.SessionId(http.User),
                        cancellationToken)
                    .ConfigureAwait(false);

                return Results.Ok(new { revoquees = nombre });
            })
            .WithName("RevokeMyOtherSessions")
            .WithSummary("Révoque toutes les sessions sauf la session courante.");

        // --- Photo de profil ---

        groupe.MapPut("/avatar", async (
                HttpRequest requete,
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                if (!requete.HasFormContentType)
                {
                    return Results.BadRequest(new { code = "avatar.multipart_required" });
                }

                var formulaire = await requete.ReadFormAsync(cancellationToken).ConfigureAwait(false);
                var fichier = formulaire.Files.GetFile("file");

                if (fichier is null || fichier.Length == 0)
                {
                    return Results.BadRequest(new { code = "avatar.file_required" });
                }

                // Le plafond est vérifié avant lecture : accepter puis rejeter un fichier
                // de 500 Mo consommerait la mémoire du serveur (NF-SEC-09).
                if (fichier.Length > IAvatarStorage.MaxBytes)
                {
                    return Results.Problem(
                        title: "L'image ne doit pas dépasser 5 Mo.",
                        statusCode: StatusCodes.Status413PayloadTooLarge,
                        extensions: new Dictionary<string, object?> { ["code"] = "avatar.too_large" });
                }

                await using var flux = fichier.OpenReadStream();

                return AuthEndpoints.Respond(
                    await service.SetAvatarAsync(
                        utilisateur.Value,
                        flux,
                        fichier.ContentType,
                        cancellationToken).ConfigureAwait(false));
            })
            .WithName("SetMyAvatar")
            .WithSummary("Téléverse une photo de profil (multipart, champ « file »).")
            .DisableAntiforgery();

        groupe.MapDelete("/avatar", async (
                AccountService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return AuthEndpoints.Respond(
                    await service.DeleteAvatarAsync(utilisateur.Value, cancellationToken)
                        .ConfigureAwait(false));
            })
            .WithName("DeleteMyAvatar")
            .WithSummary("Supprime la photo et revient à l'avatar par défaut.");

        // --- RGPD ---

        groupe.MapGet("/export", async (
                AccountDeletionService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                var resultat = await service.ExportAsync(utilisateur.Value, cancellationToken)
                    .ConfigureAwait(false);

                return resultat.IsSuccess
                    ? Results.File(
                        System.Text.Encoding.UTF8.GetBytes(resultat.Value),
                        "application/json",
                        "partyplan-mes-donnees.json")
                    : AuthEndpoints.Problem(resultat.Error!);
            })
            .WithName("ExportMyData")
            .WithSummary("Export complet des données du compte, sans intervention humaine.");

        // Le corps doit être déclaré explicitement : la méthode DELETE ne l'infère pas.
        // Si un intermédiaire réseau le supprimait, la confirmation ne correspondrait
        // plus et la suppression serait refusée — la défaillance est donc sûre.
        groupe.MapDelete("/", async (
                [FromBody] DeleteAccountRequest corps,
                AccountDeletionService service,
                HttpContext http,
                CancellationToken cancellationToken) =>
            {
                var utilisateur = AuthEndpoints.UserId(http.User);
                if (utilisateur is null)
                {
                    return Results.Unauthorized();
                }

                return AuthEndpoints.Respond(
                    await service.DeleteAsync(
                        utilisateur.Value,
                        corps.EmailConfirmation,
                        cancellationToken).ConfigureAwait(false));
            })
            .WithName("DeleteMyAccount")
            .WithSummary("Supprime le compte. Les contributions financières sont anonymisées.");
    }
}
