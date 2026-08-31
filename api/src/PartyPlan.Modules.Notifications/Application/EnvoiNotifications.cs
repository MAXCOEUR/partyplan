namespace PartyPlan.Modules.Notifications.Application;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Passe d'envoi des notifications dues (§5.12).
/// <para>
/// Deux filtres avant l'appareil : la catégorie désactivée (<c>EF-NOT-07</c>) et
/// l'événement en sourdine (<c>EF-NOT-08</c>). Tous deux horodatent tout de même la
/// ligne — sinon elle serait réexaminée à chaque réveil, indéfiniment. Aucune plage de
/// silence : le serveur ne juge plus l'heure, retirée par <c>RG-NOT-01</c>.
/// </para>
/// </summary>
public sealed class EnvoiNotifications(
    INotificationsDbContext db,
    IPushSender emetteur,
    ILogger<EnvoiNotifications> logger) : IEnvoiNotifications
{
    /// <summary>Plafond par passe. Une file énorme se vide en plusieurs réveils plutôt
    /// que de bloquer une passe pendant des minutes.</summary>
    private const int ParPasse = 200;

    public async Task<int> EnvoyerLesDuesAsync(
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        var dues = await db.Notifications
            .Where(n => n.SentAt == null
                        && n.ScheduledFor <= maintenant
                        && n.UserId != null)
            .OrderBy(n => n.ScheduledFor)
            .Take(ParPasse)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        if (dues.Count == 0)
        {
            return 0;
        }

        var destinataires = dues.Select(n => n.UserId!.Value).Distinct().ToList();

        var preferences = await db.NotificationPreferences
            .Where(p => destinataires.Contains(p.UserId))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var globales = preferences.ToDictionary(
            p => (p.UserId, p.Category),
            p => p.PushEnabled);

        var ecarts = await db.EventNotificationPreferences
            .Where(p => destinataires.Contains(p.UserId))
            .ToDictionaryAsync(
                p => (p.UserId, p.EventId, p.Category),
                p => p.Enabled,
                cancellationToken)
            .ConfigureAwait(false);

        var sourdines = (await db.EventMuteSettings
            .Where(m => destinataires.Contains(m.UserId))
            .Select(m => new { m.UserId, m.EventId })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false))
            .Select(m => (m.UserId, m.EventId))
            .ToHashSet();

        var appareils = await db.PushDevices
            .Where(d => destinataires.Contains(d.UserId) && d.DisabledAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var envoyees = 0;

        foreach (var notification in dues)
        {
            var destinataire = notification.UserId!.Value;

            if (!EstAutorisee(notification, ecarts, globales, sourdines))
            {
                // Horodatée sans partir : la personne a demandé le silence, et laisser la
                // ligne en file la ferait réexaminer à chaque réveil pour rien.
                notification.SentAt = maintenant;
                continue;
            }

            foreach (var appareil in appareils.Where(d => d.UserId == destinataire))
            {
                await emetteur
                    .SendAsync(
                        MessagePousse.Depuis(notification, appareil.Token),
                        cancellationToken)
                    .ConfigureAwait(false);
            }

            // Horodatée même sans appareil enregistré, et même si l'envoi a échoué :
            // sans cela, une notification dont le jeton est mort serait réessayée toutes
            // les minutes, indéfiniment. Perdre l'avis vaut mieux que la boucle infinie.
            notification.SentAt = maintenant;
            envoyees++;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        if (envoyees > 0)
        {
            logger.LogInformation("{Nombre} notification(s) envoyée(s).", envoyees);
        }

        return envoyees;
    }

    /// <summary>
    /// La notification est-elle autorisée à partir ?
    /// <para>
    /// L'ordre est la règle : sourdine de la soirée, puis <see cref="ResolutionPreference"/>
    /// (écart de la soirée pour cette catégorie, puis préférence globale, puis valeur
    /// d'usine). La sourdine reste une notion distincte plutôt qu'une liste de « non » —
    /// une catégorie ajoutée demain doit rester muette sur une soirée mise en sourdine, ce
    /// qu'une liste figée laisserait passer.
    /// </para>
    /// </summary>
    private static bool EstAutorisee(
        Notification n,
        Dictionary<(Guid UserId, Guid EventId, string Category), bool> ecarts,
        Dictionary<(Guid UserId, string Category), bool> globales,
        HashSet<(Guid UserId, Guid EventId)> sourdines)
    {
        var destinataire = n.UserId!.Value;

        if (n.EventId is { } evenement && sourdines.Contains((destinataire, evenement)))
        {
            return false;
        }

        var ecart = ecarts.TryGetValue((destinataire, n.EventId ?? Guid.Empty, n.Category), out var e)
            ? (bool?)e
            : null;

        var globale = globales.TryGetValue((destinataire, n.Category), out var g) ? (bool?)g : null;

        return ResolutionPreference.EstActivee(ecart, globale);
    }
}
