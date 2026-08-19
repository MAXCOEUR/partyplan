namespace PartyPlan.Modules.Events.Endpoints;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Events.Application;

internal static class EventsEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/events")
            .WithTags("Events")
            .RequireAuthorization();

        group.MapGet("/{eventId:guid}", async (
                Guid eventId,
                EventReader reader,
                CancellationToken cancellationToken) =>
            {
                var result = await reader.GetSummaryAsync(eventId, cancellationToken).ConfigureAwait(false);

                return result.IsSuccess
                    ? Results.Ok(result.Value)
                    : Results.NotFound();
            })
            .WithName("GetEvent")
            .WithSummary("Synthèse d'un événement dont l'appelant est membre.")
            .Produces<EventSummary>()
            .ProducesProblem(StatusCodes.Status404NotFound);
    }
}
