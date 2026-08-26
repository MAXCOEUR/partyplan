namespace PartyPlan.Infrastructure.TempsReel;

using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Diffusion par SignalR. Seule implémentation de <see cref="IDiffusionEvenement"/>.
/// <para>
/// Le nom de la méthode invoquée chez le client est fixe, <c>Changement</c>, et le nom du
/// message voyage en argument. Une méthode par message obligerait le client à s'abonner
/// vingt et une fois et à évoluer à chaque ajout.
/// </para>
/// </summary>
public sealed class DiffusionSignalR(
    IHubContext<EventHub> hub,
    ILogger<DiffusionSignalR> logger) : IDiffusionEvenement
{
    public async Task PublierAsync(
        Guid eventId,
        string message,
        object charge,
        CancellationToken cancellationToken)
    {
        try
        {
            await hub.Clients
                .Group(EventHub.Groupe(eventId))
                .SendAsync("Changement", message, charge, cancellationToken)
                .ConfigureAwait(false);
        }
        catch (Exception erreur) when (erreur is not OperationCanceledException)
        {
            // Aucune exception ne franchit cette frontière : une diffusion perdue ne doit
            // pas faire échouer la dépense ou l'achat qui l'a déclenchée (RG-RT-03). Le
            // client retrouvera l'état exact à sa prochaine relecture.
            logger.LogWarning(
                erreur,
                "Diffusion {Message} perdue pour l'événement {Evenement}.",
                message,
                eventId);
        }
    }
}
