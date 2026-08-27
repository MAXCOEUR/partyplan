namespace PartyPlan.Infrastructure.TempsReel;

using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Qui est connecté, à quel événement, sous quelle connexion.
/// <para>
/// SignalR sait envoyer à un groupe, mais pas retirer un compte d'un groupe : ses
/// méthodes prennent un identifiant de connexion, que rien ne relie au compte sans ce
/// registre. C'est pourtant nécessaire à l'exclusion d'un membre.
/// </para>
/// <para>
/// <b>En mémoire, et c'est admis</b> : une seule instance d'API est autorisée
/// (RG-RT-04), le hub SignalR n'ayant pas de backplane. Le jour où une seconde instance
/// s'ajoute, ce registre devra suivre le même chemin que le hub — Redis et un ADR — et
/// ce fichier est le second endroit où le regarder.
/// </para>
/// <para>
/// Un redémarrage vide le registre, sans conséquence : les connexions meurent avec le
/// processus, et la reconnexion repasse par le contrôle d'appartenance.
/// </para>
/// </summary>
public sealed class RegistreConnexions
{
    private readonly ConcurrentDictionary<string, (Guid EventId, Guid UserId)> _connexions = new();

    internal void Inscrire(string connectionId, Guid eventId, Guid userId) =>
        _connexions[connectionId] = (eventId, userId);

    internal void Retirer(string connectionId) => _connexions.TryRemove(connectionId, out _);

    /// <summary>Connexions ouvertes d'un compte sur un événement donné.</summary>
    internal IReadOnlyList<string> ConnexionsDe(Guid eventId, Guid userId) =>
    [
        .. _connexions
            .Where(c => c.Value.EventId == eventId && c.Value.UserId == userId)
            .Select(c => c.Key),
    ];
}

/// <summary>
/// Seule implémentation de <see cref="IConnexionsEvenement"/>.
/// <para>
/// Retire du groupe plutôt que d'abandonner la connexion : l'abandon ferait rejouer au
/// client sa boucle de reconnexion, qui échouerait au contrôle d'appartenance et
/// remonterait une erreur là où il n'y a rien d'anormal — quelqu'un a simplement été
/// exclu. Retiré du groupe, le client garde une connexion vivante et muette, et sa
/// prochaine ouverture d'événement sera refusée normalement.
/// </para>
/// </summary>
public sealed class ConnexionsEvenement(
    IHubContext<EventHub> hub,
    RegistreConnexions registre,
    ILogger<ConnexionsEvenement> logger) : IConnexionsEvenement
{
    public async Task FermerAsync(Guid eventId, Guid userId, CancellationToken cancellationToken)
    {
        var connexions = registre.ConnexionsDe(eventId, userId);

        if (connexions.Count == 0)
        {
            return;
        }

        foreach (var connexion in connexions)
        {
            try
            {
                await hub.Groups
                    .RemoveFromGroupAsync(connexion, EventHub.Groupe(eventId), cancellationToken)
                    .ConfigureAwait(false);
            }
            catch (Exception erreur) when (erreur is not OperationCanceledException)
            {
                // Aucune exception ne franchit cette frontière : un retrait manqué ne
                // doit pas faire échouer l'exclusion elle-même. Le membre reste exclu
                // en base, et sa prochaine connexion sera refusée de toute façon.
                logger.LogWarning(
                    erreur,
                    "Retrait du groupe {Evenement} manqué pour une connexion.",
                    eventId);
            }
        }

        logger.LogInformation(
            "{Nombre} connexion(s) retirée(s) du groupe {Evenement}.",
            connexions.Count,
            eventId);
    }
}
