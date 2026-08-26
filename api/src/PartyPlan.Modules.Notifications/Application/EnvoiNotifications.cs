namespace PartyPlan.Modules.Notifications.Application;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Passe d'envoi des notifications dues (§5.12).
/// <para>
/// Trois filtres avant l'appareil : la catégorie désactivée (<c>EF-NOT-07</c>),
/// l'événement en sourdine (<c>EF-NOT-08</c>), et la plage de silence
/// (<c>RG-NOT-01</c>). Les deux premiers horodatent tout de même la ligne — sinon elle
/// serait réexaminée à chaque réveil, indéfiniment. Le troisième ne l'horodate pas : la
/// notification part vraiment, plus tard.
/// </para>
/// </summary>
public sealed class EnvoiNotifications(
    INotificationsDbContext db,
    IUserIdentityLookup identites,
    IPushSender emetteur,
    ILogger<EnvoiNotifications> logger) : IEnvoiNotifications
{
    /// <summary>Début de la plage de silence, heure locale du destinataire.</summary>
    private const int DebutDuSilence = 22;

    /// <summary>Fin de la plage de silence.</summary>
    private const int FinDuSilence = 8;

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

        var profils = await identites
            .FindManyAsync(destinataires, cancellationToken)
            .ConfigureAwait(false);

        var preferences = await db.NotificationPreferences
            .Where(p => destinataires.Contains(p.UserId))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var sourdines = await db.EventMuteSettings
            .Where(m => destinataires.Contains(m.UserId))
            .Select(m => new { m.UserId, m.EventId })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var appareils = await db.PushDevices
            .Where(d => destinataires.Contains(d.UserId) && d.DisabledAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var envoyees = 0;

        foreach (var notification in dues)
        {
            var destinataire = notification.UserId!.Value;

            var desactivee = preferences.Any(p =>
                p.UserId == destinataire
                && p.Category == notification.Category
                && !p.PushEnabled);

            var enSourdine = notification.EventId is { } evenement
                             && sourdines.Any(s => s.UserId == destinataire
                                                   && s.EventId == evenement);

            if (desactivee || enSourdine)
            {
                // Horodatée sans partir : la personne a demandé le silence, et laisser la
                // ligne en file la ferait réexaminer à chaque réveil pour rien.
                notification.SentAt = maintenant;
                continue;
            }

            if (EnHeureCreuse(notification, profils, destinataire, maintenant))
            {
                // Pas horodatée : elle partira, plus tard. C'est bien un report et non
                // un abandon (RG-NOT-01).
                continue;
            }

            foreach (var appareil in appareils.Where(d => d.UserId == destinataire))
            {
                await emetteur
                    .SendAsync(
                        new PushMessage(
                            appareil.Token,
                            notification.Title,
                            notification.Body,
                            notification.DeepLink),
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
    /// Le destinataire est-il dans sa plage de silence (RG-NOT-01) ?
    /// <para>
    /// Le rappel de début d'événement la traverse : c'est l'exception écrite dans la
    /// règle. Une soirée qui commence à 23 h se rappelle à 21 h, et se taire alors
    /// rendrait le rappel inutile précisément quand il sert.
    /// </para>
    /// </summary>
    private bool EnHeureCreuse(
        Notification notification,
        IReadOnlyDictionary<Guid, UserIdentity> profils,
        Guid destinataire,
        DateTimeOffset maintenant)
    {
        if (notification.Category == NotificationCategories.EventStartingSoon)
        {
            return false;
        }

        var fuseau = profils.TryGetValue(destinataire, out var profil)
            ? profil.Timezone
            : "Europe/Paris";

        TimeZoneInfo zone;
        try
        {
            zone = TimeZoneInfo.FindSystemTimeZoneById(fuseau);
        }
        catch (Exception erreur)
            when (erreur is TimeZoneNotFoundException or InvalidTimeZoneException)
        {
            // Un fuseau introuvable retombe sur celui de la majorité des comptes plutôt
            // que d'écarter la personne : ne jamais notifier vaut moins bien que
            // notifier à une heure approchante.
            logger.LogWarning("Fuseau inconnu « {Fuseau} », repli sur Europe/Paris.", fuseau);
            zone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Paris");
        }

        var heureLocale = TimeZoneInfo.ConvertTime(maintenant, zone).Hour;

        return heureLocale >= DebutDuSilence || heureLocale < FinDuSilence;
    }
}
