namespace PartyPlan.Modules.Shopping.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Shopping.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Rappel des articles non attribués, la veille (<c>EF-NOT-04</c>).
/// <para>
/// À l'organisateur seul : c'est lui qui peut relancer, et prévenir tout le monde
/// qu'il reste des courses à prendre en charge produirait une notification collective
/// que personne ne s'approprie.
/// </para>
/// </summary>
public sealed class RappelsDArticles(
    IShoppingDbContext db,
    IFileNotifications notifications) : IPlanificateurRappels
{
    private static readonly TimeSpan Avance = TimeSpan.FromDays(1);

    public async Task PlanifierAsync(
        EvenementAVenir evenement,
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(evenement);

        var restant = evenement.StartsAt - maintenant;

        if (restant > Avance || restant <= TimeSpan.Zero)
        {
            return;
        }

        var orphelins = await db.ShoppingItems
            .CountAsync(
                i => i.EventId == evenement.EventId
                     && i.AssignedMemberId == null
                     && !i.IsPurchased
                     && i.DeletedAt == null,
                cancellationToken)
            .ConfigureAwait(false);

        // Une liste vide ne produit rien : il n'y a rien à signaler, et annoncer
        // « 0 article sans preneur » serait une notification pour dire qu'il ne se passe
        // rien.
        if (orphelins == 0)
        {
            return;
        }

        notifications.Enfiler(new NotificationAEnvoyer(
            evenement.OwnerUserId,
            evenement.EventId,
            NotificationCategories.ShoppingUnclaimed,
            "Il reste des courses sans preneur",
            orphelins == 1
                ? "Un article n'est pris en charge par personne, et c'est demain."
                : $"{orphelins} articles ne sont pris en charge par personne, et c'est demain.",
            $"/events/{evenement.EventId}/courses",
            maintenant,
            $"{evenement.EventId}:{NotificationCategories.ShoppingUnclaimed}:{evenement.OwnerUserId}:j-1"));
    }
}
