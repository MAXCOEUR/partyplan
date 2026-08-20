namespace PartyPlan.Modules.Shopping.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Shopping.Application;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Http;

public sealed record ShoppingItemBody(
    [Required][MaxLength(120)] string Name,
    decimal? Quantity,
    [MaxLength(20)] string? Unit,
    string? Category,
    decimal? EstimatedPrice,
    [MaxLength(500)] string? Note);

public sealed record PurchaseBody(decimal? PurchasedQuantity, decimal? ActualPrice);

/// <summary>Endpoints de la liste de courses (§8.2).</summary>
internal static class ShoppingEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/shopping")
            .WithTags("Shopping")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(
                await service.ListerAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("ListShoppingItems")
            .WithSummary("Liste de courses et avancement.")
            .Produces<ShoppingList>();

        groupe.MapPost("/", async (
                Guid eventId,
                ShoppingItemBody corps,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .AjouterAsync(eventId, Vers(corps), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("AddShoppingItem")
            .WithSummary("Ajoute un article. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency()
            .Produces<ShoppingItemView>();

        groupe.MapPatch("/{itemId:guid}", async (
                Guid eventId,
                Guid itemId,
                ShoppingItemBody corps,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .ModifierAsync(eventId, itemId, Vers(corps), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("UpdateShoppingItem")
            .WithSummary("Modifie un article.")
            .Produces<ShoppingItemView>();

        groupe.MapDelete("/{itemId:guid}", async (
                Guid eventId,
                Guid itemId,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .SupprimerAsync(eventId, itemId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("DeleteShoppingItem")
            .WithSummary("Supprime un article. Refusé si une dépense y est rattachée.");

        // Attribution : idempotente par nature, et différable hors ligne. S'attribuer
        // deux fois le même article revient à se l'attribuer une fois.
        groupe.MapPost("/{itemId:guid}/claim", async (
                Guid eventId,
                Guid itemId,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .AttribuerAsync(eventId, itemId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ClaimShoppingItem")
            .WithSummary("S'attribue un article. Attribution unique, contrôlée en base.")
            .Produces<ShoppingItemView>();

        groupe.MapDelete("/{itemId:guid}/claim", async (
                Guid eventId,
                Guid itemId,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .LibererAsync(eventId, itemId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ReleaseShoppingItem")
            .WithSummary("Retire son attribution.")
            .Produces<ShoppingItemView>();

        groupe.MapPost("/{itemId:guid}/purchase", async (
                Guid eventId,
                Guid itemId,
                PurchaseBody corps,
                ShoppingService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .AcheterAsync(
                    eventId,
                    itemId,
                    new PurchaseRequest(corps.PurchasedQuantity, corps.ActualPrice),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("PurchaseShoppingItem")
            .WithSummary("Déclare l'achat. La saisie d'un prix payé engendre la dépense.")
            .RequireIdempotency()
            .Produces<ShoppingItemView>();
    }

    private static ShoppingItemRequest Vers(ShoppingItemBody corps) => new(
        corps.Name,
        corps.Quantity,
        corps.Unit,
        corps.Category,
        corps.EstimatedPrice,
        corps.Note);
}
