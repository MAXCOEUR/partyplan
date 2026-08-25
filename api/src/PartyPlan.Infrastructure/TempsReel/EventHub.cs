namespace PartyPlan.Infrastructure.TempsReel;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Hub temps réel des événements — `RG-RT-01`, exposé sur <c>/hubs/event</c>.
/// <para>
/// Un groupe par événement, et l'appartenance est vérifiée **à l'établissement de la
/// connexion** plutôt qu'à chaque message : une vérification par message coûterait une
/// requête à chaque diffusion, et l'exclusion d'un membre ferme sa connexion.
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
    ILogger<EventHub> logger) : Hub
{
    /// <summary>Nom du groupe. Un préfixe évite toute collision avec un autre usage.</summary>
    public static string Groupe(Guid eventId) => $"event:{eventId}";

    public override async Task OnConnectedAsync()
    {
        var brut = Context.GetHttpContext()?.Request.Query["eventId"].ToString();

        if (!Guid.TryParse(brut, out var eventId))
        {
            // Aucun événement demandé : rien à écouter, on refuse plutôt que de laisser
            // une connexion inutile ouverte.
            Context.Abort();
            return;
        }

        var membre = await appartenance
            .FindCurrentAsync(eventId, Context.ConnectionAborted)
            .ConfigureAwait(false);

        if (membre is null)
        {
            // Abandon sans message : distinguer « pas membre » de « inexistant »
            // révélerait l'existence de l'événement (RG-SEC-02).
            logger.LogInformation(
                "Connexion temps réel refusée : appelant non membre de {Evenement}.",
                eventId);
            Context.Abort();
            return;
        }

        await Groups
            .AddToGroupAsync(Context.ConnectionId, Groupe(eventId), Context.ConnectionAborted)
            .ConfigureAwait(false);

        await base.OnConnectedAsync().ConfigureAwait(false);
    }
}
