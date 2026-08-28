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

/// <summary>
/// Octroi de la formule payante (EF-PRM-04).
/// <para>
/// Ni l'échéance ni le motif ne portent <c>[Required]</c> : leur absence est traitée par
/// l'endpoint, qui répond alors <c>plan.expiry_required</c> ou <c>plan.reason_required</c>.
/// Un code métier stable vaut mieux qu'un message de validation générique pour une règle
/// que le client doit pouvoir distinguer.
/// </para>
/// </summary>
public sealed record SetPlanRequest(DateTimeOffset? PremiumUntil, [MaxLength(500)] string? Reason);


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

        // Attribution de la formule payante (EF-PRM-04, ADR 0008). Réservée au
        // PlatformAdmin : RG-ADM-05 borne le rôle Support à la consultation et au
        // dépannage, et offrir un abonnement n'est ni l'un ni l'autre.
        //
        // Aucun garde SelfActionRefused ici, contrairement à suspend, delete et role.
        // RG-ADM-03 protège d'un auto-sabotage — se suspendre, se révoquer, se
        // supprimer sont des gestes dont on ne revient pas seul. S'accorder une formule
        // n'appartient pas à cette famille : c'est une faveur, elle est réversible, elle
        // est journalisée, et l'administrateur d'une instance en est le propriétaire.
        // Le jour où un encaissement existera (lot 4.1), la question se reposera.
        groupe.MapPut("/users/{userId:guid}/plan", async (
                Guid userId,
                SetPlanRequest corps,
                IUserDirectory users,
                IAuditLog audit,
                IClock clock,
                CancellationToken cancellationToken) =>
            {
                if (corps.PremiumUntil is not { } echeance)
                {
                    return Problem(ExpiryRequired);
                }

                if (echeance <= clock.UtcNow)
                {
                    return Problem(ExpiryInPast);
                }

                return await AppliquerFormuleAsync(
                        userId,
                        echeance,
                        corps.Reason,
                        users,
                        audit,
                        cancellationToken)
                    .ConfigureAwait(false);
            })
            .WithName("AdminSetPlan")
            .WithSummary("Accorde la formule payante jusqu'à une échéance, avec motif obligatoire.")
            .RequireAuthorization(AdminPolicy);

        // Le motif voyage en chaîne de requête et non dans un corps : un DELETE porteur
        // d'un corps n'est pas inféré par les endpoints minimaux, et le dépôt n'en a aucun
        // autre exemple.
        groupe.MapDelete("/users/{userId:guid}/plan", async (
                Guid userId,
                string? reason,
                IUserDirectory users,
                IAuditLog audit,
                CancellationToken cancellationToken) =>
            await AppliquerFormuleAsync(
                    userId,
                    premiumUntil: null,
                    reason,
                    users,
                    audit,
                    cancellationToken)
                .ConfigureAwait(false))
            .WithName("AdminRevokePlan")
            .WithSummary("Ramène un compte à la formule gratuite, avec motif obligatoire.")
            .RequireAuthorization(AdminPolicy);
    }

    /// <summary>
    /// Applique une échéance de formule et journalise, mais seulement si quelque chose a
    /// changé : le back-office se manipule à la main, et un double clic ne doit pas laisser
    /// deux lignes identiques dans un journal inaltérable (RG-ADM-06).
    /// </summary>
    private static async Task<IResult> AppliquerFormuleAsync(
        Guid userId,
        DateTimeOffset? premiumUntil,
        string? motif,
        IUserDirectory users,
        IAuditLog audit,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(motif))
        {
            return Problem(ReasonRequired);
        }

        var resultat = await users.SetPlanAsync(userId, premiumUntil, cancellationToken)
            .ConfigureAwait(false);

        if (resultat.IsFailure)
        {
            return Problem(resultat.Error!);
        }

        if (resultat.Value!.Changed)
        {
            await audit.RecordAsync(
                AdminAuditActions.PlanChanged,
                userId,
                motif.Trim(),
                new { precedente = resultat.Value.Previous, nouvelle = resultat.Value.Current },
                cancellationToken).ConfigureAwait(false);
        }

        return Results.NoContent();
    }

    private static readonly DomainError SelfActionRefused = DomainError.Rule(
        "admin.self_action_refused",
        "Tu ne peux pas appliquer cette action à ton propre compte.");

    private static readonly DomainError ExpiryRequired = DomainError.Validation(
        "plan.expiry_required",
        "Indique une échéance : une formule payante sans terme ne se renouvelle pas.");

    private static readonly DomainError ExpiryInPast = DomainError.Validation(
        "plan.expiry_in_past",
        "L'échéance doit être dans le futur.");

    private static readonly DomainError ReasonRequired = DomainError.Validation(
        "plan.reason_required",
        "Indique un motif : le journal d'audit doit dire pourquoi.");

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
