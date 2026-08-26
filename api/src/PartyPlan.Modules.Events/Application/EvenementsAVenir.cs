namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Seule implémentation d'<see cref="IEvenementsAVenir"/>.
/// </summary>
public sealed class EvenementsAVenir(IEventsDbContext db) : IEvenementsAVenir
{
    public async Task<IReadOnlyList<EvenementAVenir>> ListerAsync(
        DateTimeOffset maintenant,
        TimeSpan horizon,
        TimeSpan retard,
        CancellationToken cancellationToken)
    {
        var borneHaute = maintenant + horizon;
        var borneBasse = maintenant - retard;

        // IgnoreQueryFilters : seul endroit du lot 1.11 à le faire, et il faut dire
        // pourquoi. Le filtre global de cloisonnement s'appuie sur IEventScope, qui
        // n'est amorcé que par l'intergiciel d'une requête HTTP. L'ordonnanceur tourne
        // hors requête : sans cette levée, la liste renverrait zéro ligne et aucun
        // rappel ne partirait jamais.
        //
        // Acceptable ici, et seulement ici, parce que la vue rendue ne porte aucun
        // contenu d'événement — ni nom, ni adresse, ni membre. L'ordonnanceur rouvre
        // ensuite le périmètre événement par événement (IEventScope.AllowTemporarily)
        // avant d'appeler quoi que ce soit qui lise du contenu.
        return await db.Events
            .IgnoreQueryFilters()
            .Where(e => e.DeletedAt == null
                        && e.ArchivedAt == null
                        && e.StartsAt <= borneHaute
                        && (e.EndsAt ?? e.StartsAt.AddHours(12)) >= borneBasse)
            .Select(e => new EvenementAVenir(
                e.Id,
                e.CreatedByUserId,
                e.StartsAt,
                e.EndsAt))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);
    }
}
