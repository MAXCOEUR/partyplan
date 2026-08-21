namespace PartyPlan.Modules.Messages.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Messages.Application;
using PartyPlan.SharedKernel.Http;

public sealed record MessageBody(
    [MaxLength(4000)] string? Body,
    [MaxLength(512)] string? AttachmentUrl,
    Guid? ReplyToMessageId,
    Guid? PollId,
    IReadOnlyList<Guid>? MentionedMemberIds);

public sealed record ReactionBody([Required][MaxLength(16)] string Emoji);

public sealed record PinBody(Guid? FolderId);

public sealed record FolderBody([Required][MaxLength(60)] string Name);

/// <summary>Endpoints de la discussion (§8.2).</summary>
internal static class MessagesEndpoints
{
    internal static void Map(IEndpointRouteBuilder routes)
    {
        MapFil(routes);
        MapEpingles(routes);
    }

    private static void MapFil(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/messages")
            .WithTags("Messages")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(
                await service.ListerAsync(eventId, cancellationToken).ConfigureAwait(false)))
            .WithName("ListMessages")
            .WithSummary("Fil de discussion, du plus ancien au plus récent.")
            .Produces<MessagePage>();

        // Sans idempotence obligatoire, à la différence d'une dépense : un message
        // envoyé deux fois se voit et se supprime, tandis qu'une dépense en double
        // fausse silencieusement les soldes.
        groupe.MapPost("/", async (
                Guid eventId,
                MessageBody corps,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .EnvoyerAsync(eventId, Vers(corps), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("SendMessage")
            .WithSummary("Envoie un message : texte, image, réponse, mentions.")
            .Produces<MessageView>();

        groupe.MapPatch("/{messageId:guid}", async (
                Guid eventId,
                Guid messageId,
                MessageBody corps,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .ModifierAsync(eventId, messageId, Vers(corps), cancellationToken)
                .ConfigureAwait(false)))
            .WithName("EditMessage")
            .WithSummary("Modifie son propre message. La modification reste visible.")
            .Produces<MessageView>();

        groupe.MapDelete("/{messageId:guid}", async (
                Guid eventId,
                Guid messageId,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .SupprimerAsync(eventId, messageId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("DeleteMessage")
            .WithSummary("Supprime un message. Sa place subsiste, sans son contenu.");

        // PUT et non POST : la réaction est un interrupteur, et le même appel répété
        // aboutit à un état connu plutôt qu'à une accumulation.
        groupe.MapPut("/{messageId:guid}/reactions", async (
                Guid eventId,
                Guid messageId,
                ReactionBody corps,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .BasculerReactionAsync(eventId, messageId, corps.Emoji, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ToggleReaction")
            .WithSummary("Pose ou retire sa réaction.")
            .Produces<MessageView>();

        groupe.MapPost("/{messageId:guid}/pin", async (
                Guid eventId,
                Guid messageId,
                PinBody corps,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .EpinglerAsync(eventId, messageId, corps.FolderId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("PinMessage")
            .WithSummary("Épingle un message, dans un dossier ou sans rangement.")
            .Produces<PinView>();

        groupe.MapDelete("/{messageId:guid}/pin", async (
                Guid eventId,
                Guid messageId,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .DesepinglerAsync(eventId, messageId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("UnpinMessage")
            .WithSummary("Retire l'épingle d'un message.");
    }

    private static void MapEpingles(IEndpointRouteBuilder routes)
    {
        var groupe = routes.MapGroup("/events/{eventId:guid}/pins")
            .WithTags("Messages")
            .RequireAuthorization();

        groupe.MapGet("/", async (
                Guid eventId,
                Guid? folderId,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .ListerEpinglesAsync(eventId, folderId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("ListPins")
            .WithSummary("Messages épinglés et dossiers. Filtrable par dossier.")
            .Produces<PinPage>();

        groupe.MapPost("/folders", async (
                Guid eventId,
                FolderBody corps,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .CreerDossierAsync(eventId, corps.Name, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("CreatePinFolder")
            .WithSummary("Crée un dossier de rangement, partagé avec tout l'événement.")
            .Produces<PinFolderView>();

        groupe.MapDelete("/folders/{folderId:guid}", async (
                Guid eventId,
                Guid folderId,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(await service
                .SupprimerDossierAsync(eventId, folderId, cancellationToken)
                .ConfigureAwait(false)))
            .WithName("DeletePinFolder")
            .WithSummary("Supprime un dossier. Ses épingles reviennent au rangement libre.");
    }

    private static MessageRequest Vers(MessageBody corps) => new(
        corps.Body,
        corps.AttachmentUrl,
        corps.ReplyToMessageId,
        corps.PollId,
        corps.MentionedMemberIds);
}
