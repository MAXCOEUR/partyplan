namespace PartyPlan.Infrastructure.TempsReel;

using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Hub temps réel des événements — `RG-RT-01`, exposé sur <c>/hubs/event</c>.
/// <para>
/// Un groupe par événement, et l'appartenance est vérifiée **à l'établissement de la
/// connexion** plutôt qu'à chaque message : une vérification par message coûterait une
/// requête à chaque diffusion.
/// </para>
/// <para>
/// Ce choix a une contrepartie, longtemps affirmée ici sans être tenue : une connexion
/// admise le reste tant qu'elle vit. L'exclusion d'un membre passe donc par
/// <see cref="PartyPlan.SharedKernel.Contracts.IConnexionsEvenement"/>, qui le retire
/// de son groupe — sans quoi il continuerait de recevoir les montants et la discussion
/// d'une soirée dont il n'est plus membre. C'est <see cref="RegistreConnexions"/> qui
/// permet de relier un compte à ses connexions.
/// </para>
/// <para>
/// L'identifiant de l'événement voyage en chaîne de requête et non en argument de
/// méthode : le client doit être dans le bon groupe avant le premier message, et une
/// méthode d'abonnement laisserait une fenêtre où il est connecté sans être filtré.
/// </para>
/// </summary>
[Authorize]
public sealed class EventHub(
    IEventMembership appartenance,
    ILogger<EventHub> logger,
    RegistreConnexions registre) : Hub
{
    /// <summary>Nom du groupe. Un préfixe évite toute collision avec un autre usage.</summary>
    public static string Groupe(Guid eventId) => $"event:{eventId}";

    /// <summary>
    /// Message unique de refus. Volontairement muet sur la cause : distinguer « pas
    /// membre » de « événement inexistant » révélerait l'existence de l'événement
    /// (RG-SEC-02).
    /// </summary>
    private const string Refus = "Abonnement refusé.";

    public override async Task OnConnectedAsync()
    {
        var requete = Context.GetHttpContext()?.Request;

        if (!Guid.TryParse(requete?.Query["eventId"].ToString(), out var eventId))
        {
            throw new HubException(Refus);
        }

        // L'identité vient de Context.User et non de ICurrentUser. ICurrentUser lit
        // IHttpContextAccessor, qui n'est pas peuplé pendant OnConnectedAsync sur un
        // transport WebSocket : l'appelant y paraissait anonyme, donc non membre, et
        // personne ne rejoignait jamais son groupe.
        if (!Guid.TryParse(
                Context.User?.FindFirstValue(ClaimTypes.NameIdentifier),
                out var userId))
        {
            throw new HubException(Refus);
        }

        // IsMemberAsync et non FindCurrentAsync : cette dernière s'appuie sur le
        // périmètre d'événements amorcé par l'intergiciel HTTP, et SignalR exécute cette
        // méthode dans son propre périmètre d'injection, où rien n'a été amorcé.
        var membre = await appartenance
            .IsMemberAsync(eventId, userId, Context.ConnectionAborted)
            .ConfigureAwait(false);

        if (!membre)
        {
            logger.LogInformation(
                "Connexion temps réel refusée : compte non membre de {Evenement}.",
                eventId);

            // Une exception et non Context.Abort() : l'abandon est asynchrone, la
            // poignée de main se terminait donc normalement et le client se croyait
            // abonné jusqu'à la fermeture. Une HubException fait échouer la connexion
            // tout de suite, ce que le client peut voir.
            throw new HubException(Refus);
        }

        await Groups
            .AddToGroupAsync(Context.ConnectionId, Groupe(eventId), Context.ConnectionAborted)
            .ConfigureAwait(false);

        registre.Inscrire(Context.ConnectionId, eventId, userId);

        await base.OnConnectedAsync().ConfigureAwait(false);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        registre.Retirer(Context.ConnectionId);

        await base.OnDisconnectedAsync(exception).ConfigureAwait(false);
    }
}
