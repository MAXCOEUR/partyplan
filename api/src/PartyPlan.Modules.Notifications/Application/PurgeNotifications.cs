namespace PartyPlan.Modules.Notifications.Application;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Purge de l'historique des notifications.
/// <para>
/// La table <c>notifications</c> est la seule du produit qui ne fait que croître : une
/// ligne par destinataire et par rappel, message ou dépense, conservée indéfiniment pour
/// un contenu que personne ne relit passé quelques jours. Elle n'est pas un journal
/// d'audit — <c>RG-ADM-06</c> ne la concerne pas — et rien ne s'y rattache.
/// </para>
/// </summary>
public sealed class PurgeNotifications(
    INotificationsDbContext db,
    ILogger<PurgeNotifications> logger) : IPurgeNotifications
{
    /// <summary>
    /// Durée de conservation de l'historique.
    /// <para>
    /// Trente jours : le centre de notifications sert à rattraper ce qu'on a manqué, pas
    /// à consulter une soirée de l'an dernier. La borne est très au-delà de l'horizon de
    /// l'ordonnanceur — huit jours devant, deux derrière — ce qui garantit qu'une ligne
    /// supprimée ne peut plus être replanifiée : sans cet écart, la purge rendrait
    /// possible le renvoi d'un rappel déjà parti, la clé de déduplication ayant disparu
    /// avec elle.
    /// </para>
    /// </summary>
    public static readonly TimeSpan Retention = TimeSpan.FromDays(30);

    public async Task<int> PurgerAsync(
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        var limite = maintenant - Retention;

        // `SentAt != null` et non la seule ancienneté : un rappel inscrit de longue date
        // pour une soirée à venir n'est pas de l'historique, et le supprimer priverait
        // cette soirée de son rappel.
        var supprimees = await db.Notifications
            .Where(n => n.SentAt != null && n.CreatedAt < limite)
            .ExecuteDeleteAsync(cancellationToken)
            .ConfigureAwait(false);

        if (supprimees > 0)
        {
            logger.LogInformation(
                "Purge des notifications : {Supprimees} lignes antérieures au {Limite:yyyy-MM-dd}.",
                supprimees,
                limite);
        }

        return supprimees;
    }
}
