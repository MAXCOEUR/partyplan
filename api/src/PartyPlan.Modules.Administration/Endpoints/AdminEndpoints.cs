namespace PartyPlan.Modules.Administration.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Administration.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

public sealed record SuspendRequest([Required][MaxLength(500)] string Reason);

public sealed record ChangeRoleRequest([Required] string Role);

/// <summary>Entrée du journal d'audit, telle que présentée dans le back-office.</summary>
public sealed record AuditEntryView(
    Guid Id,
    string ActorEmail,
    Guid? TargetUserId,
    string Action,
    string? Reason,
    string? IpAddress,
    DateTimeOffset CreatedAt);

/// <summary>
/// Endpoints d'administration (§8.2).
/// <para>
/// Deux niveaux d'autorisation. Le rôle <c>Support</c> accède à la consultation et au
/// dépannage — cinq actions (RG-ADM-05) ; la suppression, la suspension et la gestion des
/// rôles sont réservées à <c>PlatformAdmin</c>. Traiter la demande d'un utilisateur ne
/// doit pas exiger le droit de supprimer son compte.
/// </para>
/// <para>
/// Aucun endpoint ici ne donne accès au contenu d'un événement (RG-ADM-01).
/// </para>
/// </summary>
internal static class AdminEndpoints
{
    private const string StaffPolicy = "PlatformStaff";
    private const string AdminPolicy = "PlatformAdmin";

    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/admin").WithTags("Administration");

        // --- Consultation : Support et PlatformAdmin ---

        groupe.MapGet("/users", async (
                string? search,
                int? page,
                int? pageSize,
                bool? includeDeleted,
                IUserDirectory users,
                CancellationToken cancellationToken) =>
            Results.Ok(await users.SearchAsync(
                    new UserQuery(search, page ?? 1, pageSize ?? 25, includeDeleted ?? false),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("AdminListUsers")
            .WithSummary("Liste les comptes, avec recherche et pagination.")
            .RequireAuthorization(StaffPolicy)
            .Produces<UserPage>();

        groupe.MapGet("/users/{userId:guid}", async (
                Guid userId,
                IUserDirectory users,
                CancellationToken cancellationToken) =>
            Respond(await users.GetAsync(userId, cancellationToken).ConfigureAwait(false)))
            .WithName("AdminGetUser")
            .WithSummary("Fiche technique d'un compte. Ne contient aucune donnée d'événement.")
            .RequireAuthorization(StaffPolicy)
            .Produces<UserRecord>();

        groupe.MapGet("/metrics", async (
                IUserDirectory users,
                CancellationToken cancellationToken) =>
            Results.Ok(await users.GetMetricsAsync(cancellationToken).ConfigureAwait(false)))
            .WithName("AdminMetrics")
            .WithSummary("Indicateurs d'instance.")
            .RequireAuthorization(StaffPolicy)
            .Produces<InstanceMetrics>();

        groupe.MapGet("/audit", async (
                int? page,
                int? pageSize,
                IAdministrationDbContext db,
                CancellationToken cancellationToken) =>
            {
                var numero = Math.Max(1, page ?? 1);
                var taille = Math.Clamp(pageSize ?? 50, 1, 200);

                var entrees = await db.AdminAuditEntries
                    .OrderByDescending(e => e.CreatedAt)
                    .Skip((numero - 1) * taille)
                    .Take(taille)
                    .Select(e => new AuditEntryView(
                        e.Id,
                        e.ActorEmail,
                        e.TargetUserId,
                        e.Action,
                        e.Reason,
                        e.IpAddress == null ? null : e.IpAddress.ToString(),
                        e.CreatedAt))
                    .ToListAsync(cancellationToken)
                    .ConfigureAwait(false);

                return Results.Ok(entrees);
            })
            .WithName("AdminAuditLog")
            .WithSummary("Journal d'audit, du plus récent au plus ancien.")
            .RequireAuthorization(StaffPolicy)
            .Produces<IReadOnlyList<AuditEntryView>>();

        // --- Dépannage : Support et PlatformAdmin ---

        groupe.MapPost("/users/{userId:guid}/password-reset", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                IPasswordResetTrigger trigger,
                CancellationToken cancellationToken) =>
            {
                var fiche = await users.GetAsync(userId, cancellationToken).ConfigureAwait(false);
                if (fiche.IsFailure)
                {
                    return Problem(fiche.Error!);
                }

                if (fiche.Value.Email is null)
                {
                    return Problem(DomainError.Rule(
                        "admin.no_email",
                        "Ce compte n'a pas d'adresse : aucun lien ne peut être envoyé."));
                }

                // RG-ADM-02 : un administrateur ne choisit ni ne consulte jamais un mot
                // de passe. Il déclenche l'envoi d'un lien à l'adresse enregistrée.
                await trigger.SendResetLinkAsync(fiche.Value.Email, cancellationToken)
                    .ConfigureAwait(false);

                await audit.RecordAsync(
                    AdminAuditActions.PasswordResetTriggered,
                    userId,
                    null,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.Accepted();
            })
            .WithName("AdminTriggerPasswordReset")
            .WithSummary("Envoie un lien de réinitialisation à l'adresse du compte.")
            .RequireAuthorization(StaffPolicy);

        groupe.MapDelete("/users/{userId:guid}/sessions", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                CancellationToken cancellationToken) =>
            {
                var resultat = await users.RevokeAllSessionsAsync(userId, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                await audit.RecordAsync(
                    AdminAuditActions.SessionsRevoked,
                    userId,
                    null,
                    new { revoquees = resultat.Value },
                    cancellationToken).ConfigureAwait(false);

                return Results.Ok(new { revoquees = resultat.Value });
            })
            .WithName("AdminRevokeSessions")
            .WithSummary("Révoque toutes les sessions d'un compte.")
            .RequireAuthorization(StaffPolicy);

        groupe.MapPost("/users/{userId:guid}/verify-email", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                CancellationToken cancellationToken) =>
            {
                var resultat = await users.MarkEmailVerifiedAsync(userId, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                await audit.RecordAsync(
                    AdminAuditActions.EmailVerifiedByAdmin,
                    userId,
                    null,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("AdminVerifyEmail")
            .WithSummary("Force la vérification d'une adresse, en cas de courriel non délivré.")
            .RequireAuthorization(StaffPolicy);

        groupe.MapGet("/users/{userId:guid}/export", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                CancellationToken cancellationToken) =>
            {
                var resultat = await users.ExportAsync(userId, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                // L'export est journalisé : c'est un accès à des données personnelles,
                // même effectué à la demande de la personne concernée (RG-ADM-06).
                await audit.RecordAsync(
                    AdminAuditActions.DataExported,
                    userId,
                    null,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.File(
                    System.Text.Encoding.UTF8.GetBytes(resultat.Value),
                    "application/json",
                    $"partyplan-donnees-{userId}.json");
            })
            .WithName("AdminExportUser")
            .WithSummary("Export des données d'un compte qui ne peut plus se connecter.")
            .RequireAuthorization(StaffPolicy);

        groupe.MapDelete("/users/{userId:guid}/avatar", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                CancellationToken cancellationToken) =>
            {
                var resultat = await users.RemoveAvatarAsync(userId, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                await audit.RecordAsync(
                    AdminAuditActions.AvatarRemoved,
                    userId,
                    null,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("AdminRemoveAvatar")
            .WithSummary("Supprime une photo de profil signalée comme inappropriée.")
            .RequireAuthorization(StaffPolicy);

        // --- Actions réservées à PlatformAdmin (RG-ADM-05) ---

        groupe.MapPost("/users/{userId:guid}/suspend", async (
                Guid userId,
                SuspendRequest corps,
                IUserDirectory users,
                IAuditLog audit,
                ICurrentUser currentUser,
                CancellationToken cancellationToken) =>
            {
                if (currentUser.UserId == userId)
                {
                    return Problem(SelfActionRefused);
                }

                var resultat = await users.SuspendAsync(userId, corps.Reason, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                await audit.RecordAsync(
                    AdminAuditActions.Suspended,
                    userId,
                    corps.Reason,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("AdminSuspendUser")
            .WithSummary("Suspend un compte, avec motif obligatoire. Les sessions sont révoquées.")
            .RequireAuthorization(AdminPolicy);

        groupe.MapPost("/users/{userId:guid}/unsuspend", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                CancellationToken cancellationToken) =>
            {
                var resultat = await users.UnsuspendAsync(userId, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                await audit.RecordAsync(
                    AdminAuditActions.Unsuspended,
                    userId,
                    null,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("AdminUnsuspendUser")
            .WithSummary("Réactive un compte suspendu.")
            .RequireAuthorization(AdminPolicy);

        groupe.MapDelete("/users/{userId:guid}", async (
                Guid userId,
                IUserDirectory users,
                IAuditLog audit,
                ICurrentUser currentUser,
                CancellationToken cancellationToken) =>
            {
                // RG-ADM-03 : un administrateur ne peut pas se supprimer lui-même.
                if (currentUser.UserId == userId)
                {
                    return Problem(SelfActionRefused);
                }

                var resultat = await users.AnonymizeAsync(userId, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                // L'entrée d'audit est écrite après la suppression : elle survit au
                // compte, aucune clé étrangère ne l'y rattache (RG-ADM-06).
                await audit.RecordAsync(
                    AdminAuditActions.Deleted,
                    userId,
                    null,
                    null,
                    cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("AdminDeleteUser")
            .WithSummary("Supprime un compte. Les contributions financières sont anonymisées.")
            .RequireAuthorization(AdminPolicy);

        groupe.MapPatch("/users/{userId:guid}/role", async (
                Guid userId,
                ChangeRoleRequest corps,
                IUserDirectory users,
                IAuditLog audit,
                ICurrentUser currentUser,
                CancellationToken cancellationToken) =>
            {
                if (!Enum.TryParse<PlatformRole>(corps.Role, out var role))
                {
                    return Problem(DomainError.Validation(
                        "admin.unknown_role",
                        "Rôle inconnu. Valeurs acceptées : User, Support, PlatformAdmin."));
                }

                // RG-ADM-03 : un administrateur ne peut pas se révoquer lui-même.
                if (currentUser.UserId == userId)
                {
                    return Problem(SelfActionRefused);
                }

                var resultat = await users.ChangePlatformRoleAsync(userId, role, cancellationToken)
                    .ConfigureAwait(false);

                if (resultat.IsFailure)
                {
                    return Problem(resultat.Error!);
                }

                await audit.RecordAsync(
                    AdminAuditActions.RoleChanged,
                    userId,
                    null,
                    new { role = role.ToString() },
                    cancellationToken).ConfigureAwait(false);

                return Results.NoContent();
            })
            .WithName("AdminChangeRole")
            .WithSummary("Attribue ou retire un rôle plateforme.")
            .RequireAuthorization(AdminPolicy);
    }

    private static readonly DomainError SelfActionRefused = DomainError.Rule(
        "admin.self_action_refused",
        "Tu ne peux pas appliquer cette action à ton propre compte.");

    private static IResult Respond<T>(Result<T> resultat) =>
        resultat.IsSuccess ? Results.Ok(resultat.Value) : Problem(resultat.Error!);

    private static IResult Problem(DomainError erreur) => Results.Problem(
        title: erreur.Message,
        statusCode: erreur.Kind switch
        {
            ErrorKind.Validation => StatusCodes.Status400BadRequest,
            ErrorKind.Forbidden => StatusCodes.Status403Forbidden,
            ErrorKind.NotFound => StatusCodes.Status404NotFound,
            ErrorKind.Conflict => StatusCodes.Status409Conflict,
            ErrorKind.RuleViolation => StatusCodes.Status422UnprocessableEntity,
            _ => StatusCodes.Status500InternalServerError,
        },
        extensions: new Dictionary<string, object?> { ["code"] = erreur.Code });
}
