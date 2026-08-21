namespace PartyPlan.Modules.Polls.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Polls.Application;
using PartyPlan.SharedKernel.Http;

public sealed record PollBody(
    [Required][MaxLength(300)] string Question,
    [Required] IReadOnlyList<string> Options,
    bool AllowMultiple);

public sealed record VoteBody(IReadOnlyList<Guid>? OptionIds);

/// <summary>Endpoints des sondages (§8.2).</summary>
internal static class PollsEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/polls")
            .WithTags("Polls")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                PollService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(
                await service.ListerAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("ListPolls")
            .WithSummary("Sondages de l'événement, les ouverts d'abord.")
            .Produces<PollPage>();

        groupe.MapPost("/", async (
                Guid eventId,
                PollBody corps,
                PollService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .CreerAsync(
                    eventId,
                    new PollRequest(corps.Question, corps.Options, corps.AllowMultiple),
                    cancellationToken)
                .ConfigureAwait(false)))
            .WithName("CreatePoll")
            .WithSummary("Lance un sondage, annoncé dans la discussion.")
            .Produces<PollView>();

        // PUT : les choix remplacent les précédents, et le même appel répété aboutit au
        // même état. Un POST laisserait croire qu'une seconde voix s'ajoute.
        groupe.MapPut("/{pollId:guid}/votes", async (
                Guid eventId,
                Guid pollId,
                VoteBody corps,
                PollService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .VoterAsync(eventId, pollId, corps.OptionIds ?? [], cancellationToken)
                .ConfigureAwait(false)))
            .WithName("Vote")
            .WithSummary("Enregistre ses choix. Une liste vide annule son vote.")
            .Produces<PollView>();

        groupe.MapPost("/{pollId:guid}/close", async (
                Guid eventId,
                Guid pollId,
                PollService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .ClorAsync(eventId, pollId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ClosePoll")
            .WithSummary("Clôt le sondage. Son auteur, ou l'organisateur.")
            .Produces<PollView>();

        groupe.MapDelete("/{pollId:guid}", async (
                Guid eventId,
                Guid pollId,
                PollService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .SupprimerAsync(eventId, pollId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("DeletePoll")
            .WithSummary("Supprime le sondage.");
    }
}
