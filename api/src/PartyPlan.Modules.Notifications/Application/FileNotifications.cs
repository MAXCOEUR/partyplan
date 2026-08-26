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

        if (EstPlafonnee(notification))
        {
            return;
        }

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

    /// <summary>
    /// Le plafond de <c>RG-NOT-02</c> : au maximum une notification d'activité par
    /// événement, par destinataire et par quart d'heure.
    /// <para>
    /// Sans lui, une liste de courses remplie à plusieurs produirait une notification par
    /// article, et la première soirée un peu active ferait couper les notifications.
    /// </para>
    /// <para>
    /// C'est le seul endroit du lot qui regarde le passé avant d'écrire. Assumé : la
    /// règle parle d'une fenêtre glissante et non d'une clé, et une clé ne sait pas
    /// exprimer « depuis moins de quinze minutes ».
    /// </para>
    /// </summary>
    private bool EstPlafonnee(NotificationAEnvoyer notification)
    {
        if (notification.Category != NotificationCategories.Activity)
        {
            return false;
        }

        var depuis = notification.ScheduledFor - Fenetre;

        return db.Notifications.Any(n =>
            n.Category == NotificationCategories.Activity
            && n.UserId == notification.UserId
            && n.EventId == notification.EventId
            && n.ScheduledFor >= depuis);
    }

    /// <summary>Fenêtre de regroupement de RG-NOT-02.</summary>
    private static readonly TimeSpan Fenetre = TimeSpan.FromMinutes(15);
}
