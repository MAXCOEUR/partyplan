namespace PartyPlan.Modules.Messages.Endpoints;

using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using PartyPlan.Modules.Messages.Application;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Http;

/// <summary>Jusqu'où la discussion a été lue.</summary>
public sealed record LectureBody(Guid MessageId);

public sealed record MessageBody(
    [MaxLength(4000)] string? Body,
    [MaxLength(512)] string? AttachmentUrl,
    Guid? ReplyToMessageId,
    Guid? PollId,
    IReadOnlyList<Guid>? MentionedMemberIds);

public sealed record ReactionBody([Required][MaxLength(16)] string Emoji);

public sealed record PinBody(Guid? FolderId);

public sealed record FolderBody([Required][MaxLength(60)] string Name);

/// <summary>Adresse d'une image déposée, à joindre ensuite à un message.</summary>
public sealed record ImageDeposee(string Url);

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
                Guid? before,
                int? limit,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(
                await service.ListerAsync(eventId, before, limit, cancellationToken)
                    .ConfigureAwait(false)))
            .WithName("ListMessages")
            .WithSummary(
                "Fil de discussion : les derniers messages, du plus ancien au plus "
                + "récent. `before` remonte vers les plus anciens.")
            .Produces<MessagePage>();

        // Repère de lecture. Sans corps de réponse : l'application connaît déjà le
        // message qu'elle vient de marquer, et le fil rendra le nouveau compte.
        groupe.MapPost("/read", async (
                Guid eventId,
                LectureBody corps,
                MessageService service,
                CancellationToken cancellationToken) =>
            ResultatHttp.Repondre(
                await service.MarquerLuAsync(eventId, corps.MessageId, cancellationToken)
                    .ConfigureAwait(false)))
            .WithName("MarkMessagesRead")
            .WithSummary("Avance le repère de lecture jusqu'à ce message.");

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

        // Multipart : le fichier ne passe pas en JSON, et l'encoder en base64
        // gonflerait la requête d'un tiers pour rien.
        groupe.MapPost("/images", async (
                Guid eventId,
                HttpRequest requete,
                MessageService service,
                CancellationToken cancellationToken) =>
            {
                if (!requete.HasFormContentType)
                {
                    return Results.BadRequest(new { code = "message.multipart_required" });
                }

                var formulaire = await requete.ReadFormAsync(cancellationToken)
                    .ConfigureAwait(false);

                var fichier = formulaire.Files.GetFile("file");

                if (fichier is null || fichier.Length == 0)
                {
                    return Results.BadRequest(new { code = "message.file_required" });
                }

                // Le plafond est vérifié avant lecture : accepter puis rejeter un
                // fichier de vingt mégaoctets ferait attendre pour rien.
                if (fichier.Length > IEventImageStorage.MaxBytes)
                {
                    return Results.BadRequest(new { code = "message.image_too_large" });
                }

                await using var contenu = fichier.OpenReadStream();

                var resultat = await service
                    .EnvoyerImageAsync(
                        eventId,
                        contenu,
                        fichier.ContentType,
                        cancellationToken)
                    .ConfigureAwait(false);

                // L'adresse est enveloppée dans un objet : une chaîne nue en corps de
                // réponse se prête mal à l'ajout d'un champ, et il en viendra un —
                // largeur, hauteur, poids.
                return resultat.IsSuccess
                    ? Results.Ok(new ImageDeposee(resultat.Value!))
                    : ResultatHttp.Probleme(resultat.Error!);
            })
            .WithName("UploadMessageImage")
            .WithSummary("Dépose une image, réduite et débarrassée de ses métadonnées.")
            .DisableAntiforgery();

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
