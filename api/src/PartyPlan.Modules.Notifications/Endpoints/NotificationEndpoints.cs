namespace PartyPlan.Modules.Notifications.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Notifications.Application;
using PartyPlan.SharedKernel.Http;

/// <summary>Réglage d'une catégorie (EF-NOT-07).</summary>
public sealed record PreferenceBody(
    [Required][MaxLength(60)] string Category,
    bool PushEnabled,
    bool EmailEnabled);

/// <summary>Mise en sourdine d'un événement (EF-NOT-08).</summary>
public sealed record SourdineBody(bool Muted);

/// <summary>Endpoints des notifications reçues et des préférences (§8.2).</summary>
internal static class NotificationEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        MapNotifications(routes);
        MapSourdine(routes);
    }

    private static void MapNotifications(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/notifications")
            .WithTags("Notifications")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid? before,
                int? limit,
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .ListerAsync(
                    before,
                    limit ?? NotificationService.LimiteParDefaut,
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ListNotifications")
            .WithSummary("Notifications reçues, de la plus récente à la plus ancienne.")
            .WithDescription(
                "`before` remonte vers le passé. Seules les notifications déjà parties "
                + "sont rendues : une ligne encore en file n'a pas été reçue.")
            .Produces<NotificationPage>();

        groupe.MapPost("/{id:guid}/read", async (
                Guid id,
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .MarquerLueAsync(id, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("MarkNotificationRead")
            .WithSummary("Marque une notification comme lue. Idempotent.");

        groupe.MapPost("/read-all", async (
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .ToutMarquerLuAsync(cancellationToken)
                .ConfigureAwait(false)))
            .WithName("MarkAllNotificationsRead")
            .WithSummary("Marque toutes les notifications comme lues.");

        groupe.MapGet("/preferences", async (
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .PreferencesAsync(cancellationToken)
                .ConfigureAwait(false)))
            .WithName("GetNotificationPreferences")
            .WithSummary("Préférences par catégorie. Les sept sont toujours rendues.")
            .Produces<IReadOnlyList<PreferenceView>>();

        groupe.MapPatch("/preferences", async (
                PreferenceBody corps,
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .DefinirPreferenceAsync(
                    corps.Category,
                    corps.PushEnabled,
                    corps.EmailEnabled,
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("SetNotificationPreference")
            .WithSummary("Active ou désactive une catégorie.")
            .ProducesValidationProblem();
    }

    private static void MapSourdine(IEndpointRouteBuilder routes)
    {
        // Route sous /events, mais déclarée par ce module : event_mute_settings lui
        // appartient, et la règle 6 interdit au module Events d'y toucher.
        var groupe = routes.MapGroup("/events/{eventId:guid}/mute")
            .WithTags("Notifications")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .SourdineAsync(eventId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("GetEventMute")
            .WithSummary("L'événement est-il en sourdine ?")
            .Produces<bool>();

        groupe.MapPut("/", async (
                Guid eventId,
                SourdineBody corps,
                NotificationService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .DefinirSourdineAsync(eventId, corps.Muted, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("SetEventMute")
            .WithSummary("Met l'événement en sourdine, ou l'en sort. Idempotent.");
    }
}
