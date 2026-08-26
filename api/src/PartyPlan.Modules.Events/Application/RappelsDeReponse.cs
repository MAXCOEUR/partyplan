namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Rappels de non-réponse à J-3 et J-1 (<c>EF-NOT-03</c>).
/// <para>
/// Adressés aux seuls membres restés au statut <c>Unknown</c> : relancer quelqu'un qui a
/// déjà répondu est le meilleur moyen de lui faire couper les notifications.
/// </para>
/// </summary>
public sealed class RappelsDeReponse(
    IEventsDbContext db,
    IFileNotifications notifications) : IPlanificateurRappels
{
    /// <summary>
    /// Les deux échéances de la règle. Un rappel n'est inscrit qu'une fois sa date
    /// atteinte : l'inscrire d'avance rendrait la file illisible et obligerait à la
    /// nettoyer quand quelqu'un répond entre-temps.
    /// </summary>
    private static readonly (int Jours, string Occurrence)[] Echeances =
    [
        (3, "j-3"),
        (1, "j-1"),
    ];

    public async Task PlanifierAsync(
        EvenementAVenir evenement,
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(evenement);

        // Passé le début, relancer n'a plus de sens.
        if (evenement.StartsAt <= maintenant)
        {
            return;
        }

        var restant = evenement.StartsAt - maintenant;

        var echeance = Echeances.FirstOrDefault(e =>
            restant <= TimeSpan.FromDays(e.Jours));

        if (echeance.Occurrence is null)
        {
            return;
        }

        var sansReponse = await db.EventMembers
            .Where(m => m.EventId == evenement.EventId
                        && m.Status == EventMemberStatus.Unknown
                        && m.UserId != null
                        && m.RemovedAt == null)
            .Select(m => m.UserId!.Value)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var destinataire in sansReponse)
        {
            notifications.Enfiler(new NotificationAEnvoyer(
                destinataire,
                evenement.EventId,
                NotificationCategories.InvitationPending,
                "Tu n'as pas encore répondu",
                echeance.Jours == 1
                    ? "La soirée est demain. Dis si tu viens."
                    : "La soirée est dans trois jours. Dis si tu viens.",
                $"/events/{evenement.EventId}",
                maintenant,
                Cle(evenement.EventId, destinataire, echeance.Occurrence)));
        }
    }

    private static string Cle(Guid eventId, Guid destinataire, string occurrence) =>
        $"{eventId}:{NotificationCategories.InvitationPending}:{destinataire}:{occurrence}";
}
