namespace PartyPlan.Modules.Notifications.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Notifications.Application;
using PartyPlan.SharedKernel.Http;

/// <summary>Appareil à inscrire pour recevoir les notifications.</summary>
public sealed record DeviceBody(
    [Required][MaxLength(4096)] string Token,
    [Required][MaxLength(20)] string Platform);

/// <summary>
/// Endpoints des appareils (§8.2).
/// <para>
/// Déclarés par le module Notifications et non par <c>MeEndpoints</c>, bien que la route
/// commence par « /me » : <c>push_devices</c> appartient à ce module, et la règle 6
/// interdit au module Users d'y toucher.
/// </para>
/// </summary>
internal static class DeviceEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/me/devices")
            .WithTags("Notifications")
            .RequireAuthorization();

        groupe.MapPost("/", async (
                DeviceBody corps,
                DeviceService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .EnregistrerAsync(corps.Token, corps.Platform, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("RegisterDevice")
            .WithSummary("Inscrit l'appareil courant. Idempotent sur le jeton.")
            .ProducesValidationProblem();

        groupe.MapDelete("/{token}", async (
                string token,
                DeviceService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .RetirerAsync(token, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("UnregisterDevice")
            .WithSummary("Retire l'appareil. Réussit même si le jeton est inconnu.");
    }
}
