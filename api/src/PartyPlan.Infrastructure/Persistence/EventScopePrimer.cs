namespace PartyPlan.Infrastructure.Persistence;

using Microsoft.EntityFrameworkCore;
using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Calcule le périmètre d'événements de l'appelant, une fois par requête.
/// <para>
/// Le coût est d'une requête indexée par requête HTTP. C'est le prix assumé de la
/// garantie RG-SEC-01 : sans périmètre calculé côté serveur, le cloisonnement
/// reposerait sur la bonne foi de chaque requête applicative.
/// </para>
/// </summary>
public sealed class EventScopePrimer(PartyPlanDbContext db, ICurrentUser currentUser, IEventScope scope)
{
    public async Task PrimeAsync(CancellationToken cancellationToken)
    {
        if (scope.IsPrimed)
        {
            return;
        }

        if (currentUser.UserId is not { } userId)
        {
            // Appelant sans compte : aucun événement visible. Les endpoints publics
            // d'invitation élargissent explicitement le périmètre le temps de leur
            // traitement (IEventScope.AllowTemporarily).
            scope.Prime([]);
            return;
        }

        // IgnoreQueryFilters est indispensable ici : la requête qui établit le
        // périmètre ne peut pas être soumise au filtre qu'elle alimente.
        var eventIds = await db.EventMembers
            .IgnoreQueryFilters()
            .Where(m => m.UserId == userId && m.RemovedAt == null)
            .Select(m => m.EventId)
            .Distinct()
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        scope.Prime(eventIds);
    }
}
