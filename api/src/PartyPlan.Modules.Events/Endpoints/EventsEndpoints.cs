namespace PartyPlan.Modules.Events.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using PartyPlan.Modules.Events.Application;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

public sealed record CreateEventBody(
    [Required][MaxLength(120)] string Name,
    [MaxLength(4000)] string? Description,
    [Required] DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    [MaxLength(300)] string? Address);

public sealed record UpdateEventBody(
    [MaxLength(120)] string? Name,
    [MaxLength(4000)] string? Description,
    DateTimeOffset? StartsAt,
    DateTimeOffset? EndsAt,
    [MaxLength(300)] string? Address);

public sealed record JoinBody(
    [Required][MaxLength(120)] string DisplayName,
    [Required] string Status,
    TimeOnly? ArrivalTime);

public sealed record AttendanceBody(
    [Required] string Status,
    TimeOnly? ArrivalTime,
    TimeOnly? DepartureTime,
    int? ExtraGuests);

public sealed record JoinEnabledBody(bool JoinEnabled);

/// <summary>Endpoints des événements, des invitations et des présences (§8.2).</summary>
internal static class EventsEndpoints
{
    /// <summary>Limitation de la résolution de code court (RG-INV-03).</summary>
    private const string ShortCodePolicy = "short-code";

    internal static void Map(IEndpointRouteBuilder routes)
    {
        MapEvents(routes);
        MapJoin(routes);
        MapMembers(routes);
    }

    private static void MapEvents(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events").WithTags("Events").RequireAuthorization();

        groupe.MapGet("/", async (EventService service, CancellationToken cancellationToken) =>
                Results.Ok(await service.ListerAsync(cancellationToken).ConfigureAwait(false)))
            .WithName("ListEvents")
            .WithSummary("Événements de l'appelant, à venir puis passés.")
            .Produces<IReadOnlyList<EventListItem>>();

        groupe.MapPost("/", async (
                CreateEventBody corps,
                EventService service,
                CancellationToken cancellationToken) =>
            Respond(await service.CreateAsync(
                    new CreateEventRequest(
                        corps.Name,
                        corps.Description,
                        corps.StartsAt,
                        corps.EndsAt,
                        corps.Address),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("CreateEvent")
            .WithSummary("Crée un événement. En-tête Idempotency-Key obligatoire.")
            // Un double appui sur « créer » produirait deux soirées, que l'organisateur
            // devrait ensuite supprimer après avoir peut-être déjà partagé le mauvais
            // lien (§8.1).
            .RequireIdempotency()
            .Produces<EventSummary>();

        groupe.MapGet("/{eventId:guid}", async (
                Guid eventId,
                EventService service,
                CancellationToken cancellationToken) =>
            Respond(await service.LireAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("GetEvent")
            .WithSummary("Synthèse d'un événement dont l'appelant est membre.")
            .Produces<EventSummary>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        groupe.MapPatch("/{eventId:guid}", async (
                Guid eventId,
                UpdateEventBody corps,
                EventService service,
                CancellationToken cancellationToken) =>
            Respond(await service.ModifierAsync(
                    eventId,
                    new UpdateEventRequest(
                        corps.Name,
                        corps.Description,
                        corps.StartsAt,
                        corps.EndsAt,
                        corps.Address),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("UpdateEvent")
            .WithSummary("Modifie l'événement. Un changement de date ou de lieu est journalisé.")
            .Produces<EventSummary>();

        groupe.MapDelete("/{eventId:guid}", async (
                Guid eventId,
                bool? force,
                EventService service,
                CancellationToken cancellationToken) =>
            Respond(await service.SupprimerAsync(eventId, force ?? false, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("DeleteEvent")
            .WithSummary("Supprime l'événement. Confirmation renforcée exigée par « force ».");

        // --- Invitation ---

        groupe.MapGet("/{eventId:guid}/invitation", async (
                Guid eventId,
                EventService service,
                IConfiguration configuration,
                CancellationToken cancellationToken) =>
            Respond(await service
                .LireInvitationAsync(eventId, BaseUrl(configuration), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("GetInvitation")
            .WithSummary("Lien, code court et état d'ouverture de l'événement.")
            .Produces<EventInvitation>();

        groupe.MapPost("/{eventId:guid}/invitation/rotate", async (
                Guid eventId,
                EventService service,
                IConfiguration configuration,
                CancellationToken cancellationToken) =>
            Respond(await service
                .RegenererLienAsync(eventId, BaseUrl(configuration), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("RotateInvitation")
            .WithSummary("Régénère lien et code court. Les précédents deviennent invalides.")
            .Produces<EventInvitation>();

        groupe.MapPatch("/{eventId:guid}/join-enabled", async (
                Guid eventId,
                JoinEnabledBody corps,
                EventService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .DefinirOuvertureAsync(eventId, corps.JoinEnabled, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("SetJoinEnabled")
            .WithSummary("Ouvre ou ferme les nouvelles arrivées.");
    }

    private static void MapJoin(IEndpointRouteBuilder routes)
    {
        // Groupe public : par construction, l'appelant n'est pas encore membre. C'est le
        // jeton ou le code qui autorise l'accès, et la vue renvoyée est restreinte à ce
        // que RG-INV-04 permet.
        var groupe = routes.MapGroup("/join").WithTags("Invitations");

        groupe.MapGet("/{token}", async (
                string token,
                JoinService service,
                CancellationToken cancellationToken) =>
            Respond(await service.ApercuParJetonAsync(token, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("PreviewInvitation")
            .WithSummary("Aperçu restreint : nom, date, lieu, nombre de participants.")
            .Produces<JoinPreview>();

        groupe.MapGet("/code/{shortCode}", async (
                string shortCode,
                JoinService service,
                CancellationToken cancellationToken) =>
            Respond(await service.ApercuParCodeAsync(shortCode, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("PreviewByShortCode")
            .WithSummary("Résolution d'un code court PLAN-XXXXXX.")
            // RG-INV-03 : dix tentatives par minute. Sans cette limite, six caractères
            // resteraient énumérables.
            .RequireRateLimiting(ShortCodePolicy)
            .Produces<JoinPreview>();

        // Écriture susceptible d'être mise en file par le client hors ligne
        // (NF-OFFLINE-01) : le rejeu doit rendre la réponse mémorisée, jamais créer un
        // second membre.
        groupe.MapPost("/{token}", async (
                string token,
                JoinBody corps,
                JoinService service,
                CancellationToken cancellationToken) =>
            {
                if (!Enum.TryParse<EventMemberStatus>(corps.Status, out var statut))
                {
                    return Problem(AttendanceService.UnknownStatus);
                }

                return Respond(await service
                    .RejoindreAsync(token, corps.DisplayName, statut, corps.ArrivalTime, cancellationToken)
                    .ConfigureAwait(false));
            })
            .WithName("JoinEvent")
            .WithSummary("Rejoint l'événement. Aucun compte n'est exigé. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency()
            .Produces<JoinResult>();
    }

    private static void MapMembers(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/members")
            .WithTags("Presences")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                AttendanceService service,
                CancellationToken cancellationToken) =>
            Respond(await service.ListerAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("ListMembers")
            .WithSummary("Participants, avec statut et horaires.")
            .Produces<IReadOnlyList<MemberView>>();

        groupe.MapPatch("/me", async (
                Guid eventId,
                AttendanceBody corps,
                AttendanceService service,
                CancellationToken cancellationToken) =>
            Respond(await service.DeclarerAsync(
                    eventId,
                    new SetAttendanceRequest(
                        corps.Status,
                        corps.ArrivalTime,
                        corps.DepartureTime,
                        corps.ExtraGuests),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("SetMyAttendance")
            .WithSummary("Déclare sa présence. Chacun ne modifie que la sienne.")
            .Produces<MemberView>();

        groupe.MapDelete("/me", async (
                Guid eventId,
                AttendanceService service,
                CancellationToken cancellationToken) =>
            Respond(await service.QuitterAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("LeaveEvent")
            .WithSummary("Quitte l'événement. Le propriétaire doit d'abord transférer.");

        groupe.MapDelete("/{memberId:guid}", async (
                Guid eventId,
                Guid memberId,
                AttendanceService service,
                CancellationToken cancellationToken) =>
            Respond(await service.ExclureAsync(eventId, memberId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("RemoveMember")
            .WithSummary("Exclut un participant. Ses données financières subsistent.");

        // Même raison que l'adhésion : mise en file possible hors ligne, donc rejeu
        // possible. Sans idempotence, le second appel échouerait — l'appelant n'étant
        // plus propriétaire — et le client afficherait une erreur pour une action qui a
        // pourtant abouti.
        groupe.MapPost("/{memberId:guid}/transfer-ownership", async (
                Guid eventId,
                Guid memberId,
                AttendanceService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .TransfererProprieteAsync(eventId, memberId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("TransferOwnership")
            .WithSummary("Transfère la propriété. L'ancien propriétaire devient administrateur. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency();
    }

    private static string BaseUrl(IConfiguration configuration) =>
        configuration["App:PublicBaseUrl"] ?? "http://localhost:8080";

    private static IResult Respond<T>(Result<T> resultat) =>
        resultat.IsSuccess ? Results.Ok(resultat.Value) : Problem(resultat.Error!);

    private static IResult Respond(Result resultat) =>
        resultat.IsSuccess ? Results.NoContent() : Problem(resultat.Error!);

    private static IResult Problem(DomainError erreur) => Results.Problem(
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
