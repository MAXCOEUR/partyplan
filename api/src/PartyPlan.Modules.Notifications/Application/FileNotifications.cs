namespace PartyPlan.Modules.Notifications.Application;

using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Seule implémentation de <see cref="IFileNotifications"/>.
/// </summary>
public sealed class FileNotifications(
    INotificationsDbContext db,
    IClock clock,
    IIdGenerator ids) : IFileNotifications
{
    /// <summary>
    /// Clés déjà inscrites dans cette portée.
    /// <para>
    /// La contrainte d'unicité en base ne suffit pas seule : deux appels identiques dans
    /// la même requête échoueraient à la sauvegarde, avant même de l'atteindre, et
    /// feraient tomber l'action métier qui les a produits.
    /// </para>
    /// </summary>
    private readonly HashSet<string> _dejaEnfilees = [];

    public void Enfiler(NotificationAEnvoyer notification)
    {
        ArgumentNullException.ThrowIfNull(notification);

        if (!_dejaEnfilees.Add(notification.DedupKey))
        {
            return;
        }

        // Une clé déjà en base est le cas normal d'un balayage rejoué. La lecture est
        // faite ici plutôt que laissée à la contrainte, parce qu'un conflit de clé ferait
        // échouer le SaveChangesAsync de l'appelant — donc l'action métier elle-même.
        // La contrainte reste la garantie de dernier recours contre deux processus.
        if (db.Notifications.Any(n => n.DedupKey == notification.DedupKey))
        {
            return;
        }

        // Aucun plafond depuis le 30/08/2026 : chaque geste produit sa notification, et
        // c'est la clé de groupe de l'appareil qui les empile sous un seul bandeau. Le
        // plafond au quart d'heure retardait la discussion au-delà de la conversation
        // qu'il annonçait.

        db.Notifications.Add(new Notification
        {
            Id = ids.NewId(),
            UserId = notification.UserId,
            EventId = notification.EventId,
            Category = notification.Category,
            Title = notification.Title,
            Body = notification.Body,
            DeepLink = notification.DeepLink,
            ScheduledFor = notification.ScheduledFor,
            CreatedAt = clock.UtcNow,
            DedupKey = notification.DedupKey,
        });

        // Aucun SaveChangesAsync : la ligne appartient à la transaction de l'appelant.
    }
}
