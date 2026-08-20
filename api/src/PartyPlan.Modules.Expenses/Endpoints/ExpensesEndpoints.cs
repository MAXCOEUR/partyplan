namespace PartyPlan.Modules.Expenses.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Expenses.Application;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Http;
using PartyPlan.SharedKernel.Primitives;

public sealed record ShareBody([Required] Guid MemberId, int Share);

public sealed record ExpenseBody(
    [Required][MaxLength(160)] string Label,
    decimal Amount,
    Guid? PaidByMemberId,
    DateTimeOffset? SpentAt,
    string? Mode,
    IReadOnlyList<ShareBody>? Shares);

/// <summary>Endpoints des dépenses (§8.2).</summary>
internal static class ExpensesEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/expenses")
            .WithTags("Expenses")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                ExpenseService service,
                CancellationToken cancellationToken) =>
            Respond(await service.ListerAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("ListExpenses")
            .WithSummary("Dépenses de l'événement, avec les totaux.")
            .Produces<ExpensesPage>();

        groupe.MapGet("/{expenseId:guid}", async (
                Guid eventId,
                Guid expenseId,
                ExpenseService service,
                CancellationToken cancellationToken) =>
            Respond(await service.DetailAsync(eventId, expenseId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("GetExpense")
            .WithSummary("Détail d'une dépense : payeur, participants, part de chacun.")
            .Produces<ExpenseDetail>();

        // Écriture susceptible d'être mise en file par le client hors ligne : un double
        // envoi ne doit jamais créer deux dépenses (§8.1).
        groupe.MapPost("/", async (
                Guid eventId,
                ExpenseBody corps,
                ExpenseService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .CreerAsync(eventId, Vers(corps), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("CreateExpense")
            .WithSummary("Crée une dépense. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency()
            .Produces<ExpenseDetail>();

        groupe.MapPatch("/{expenseId:guid}", async (
                Guid eventId,
                Guid expenseId,
                ExpenseBody corps,
                ExpenseService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .ModifierAsync(eventId, expenseId, Vers(corps), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("UpdateExpense")
            .WithSummary("Modifie une dépense. L'état précédent est conservé.")
            .Produces<ExpenseDetail>();

        groupe.MapDelete("/{expenseId:guid}", async (
                Guid eventId,
                Guid expenseId,
                ExpenseService service,
                CancellationToken cancellationToken) =>
            Respond(await service
                .SupprimerAsync(eventId, expenseId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("DeleteExpense")
            .WithSummary("Supprime une dépense. La trace subsiste, les soldes sont recalculés.");
    }

    private static ExpenseRequest Vers(ExpenseBody corps) => new(
        corps.Label,
        corps.Amount,
        corps.PaidByMemberId,
        corps.SpentAt,
        corps.Mode,
        corps.Shares is null
            ? null
            : [.. corps.Shares.Select(s => new ShareRequest(s.MemberId, s.Share))]);

    private static IResult Respond<T>(Result<T> resultat) => ResultatHttp.Repondre(resultat);

    private static IResult Respond(Result resultat) => ResultatHttp.Repondre(resultat);
}
