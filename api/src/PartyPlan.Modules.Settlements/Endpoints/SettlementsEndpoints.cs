namespace PartyPlan.Modules.Settlements.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Settlements.Application;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Http;

public sealed record MarkSettlementBody(
    [Required] Guid FromMemberId,
    [Required] Guid ToMemberId,
    decimal Amount);

/// <summary>Endpoints des remboursements (§8.2).</summary>
internal static class SettlementsEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/settlements")
            .WithTags("Settlements")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                SettlementService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(
                await service.ConsulterAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("GetSettlements")
            .WithSummary("Soldes, règlements proposés et règlements effectués.")
            .Produces<SettlementsPage>();

        // Idempotent : cette écriture peut être mise en file hors ligne, et un rejeu ne
        // doit pas enregistrer deux fois le même remboursement.
        groupe.MapPost("/", async (
                Guid eventId,
                MarkSettlementBody corps,
                SettlementService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .MarquerAsync(
                    eventId,
                    new MarkSettlementRequest(corps.FromMemberId, corps.ToMemberId, corps.Amount),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("MarkSettlement")
            .WithSummary("Marque un remboursement comme effectué. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency()
            .Produces<SettlementsPage>();

        groupe.MapDelete("/{settlementId:guid}", async (
                Guid eventId,
                Guid settlementId,
                SettlementService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .AnnulerAsync(eventId, settlementId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("CancelSettlement")
            .WithSummary("Annule un marquage. La ligne subsiste, horodatée comme annulée.")
            .Produces<SettlementsPage>();
    }
}
