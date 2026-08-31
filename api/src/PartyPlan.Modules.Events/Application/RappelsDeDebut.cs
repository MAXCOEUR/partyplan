namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Rappel de début, deux heures avant (<c>EF-NOT-05</c>).
/// <para>
/// Aux seuls membres comptés présents : rappeler une soirée à quelqu'un qui a dit non
/// est au mieux inutile, au pire vexant.
/// </para>
/// </summary>
public sealed class RappelsDeDebut(
    IEventsDbContext db,
    IFileNotifications notifications) : IPlanificateurRappels
{
    private static readonly TimeSpan Avance = TimeSpan.FromHours(2);

    /// <summary>
    /// Statuts comptés comme présents. Reprend RG-PRES-02 : arriver en retard ou partir
    /// tôt reste venir.
    /// </summary>
    private static readonly EventMemberStatus[] Presents =
    [
        EventMemberStatus.Going,
        EventMemberStatus.Late,
        EventMemberStatus.EarlyLeave,
    ];

    public async Task PlanifierAsync(
        EvenementAVenir evenement,
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(evenement);

        var restant = evenement.StartsAt - maintenant;

        // La fenêtre est ouverte entre deux heures avant et le début. Après, le rappel
        // n'a plus d'objet ; avant, il est prématuré.
        if (restant > Avance || restant <= TimeSpan.Zero)
        {
            return;
        }

        var presents = await db.EventMembers
            .Where(m => m.EventId == evenement.EventId
                        && Presents.Contains(m.Status)
                        && m.UserId != null
                        && m.RemovedAt == null)
            .Select(m => m.UserId!.Value)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var destinataire in presents)
        {
            notifications.Enfiler(new NotificationAEnvoyer(
                destinataire,
                evenement.EventId,
                NotificationCategories.EventStartingSoon,
                "C'est bientôt",
                "La soirée commence dans deux heures.",
                $"/events/{evenement.EventId}",
                maintenant,
                $"{evenement.EventId}:{NotificationCategories.EventStartingSoon}:{destinataire}:debut"));
        }
    }
}
