namespace PartyPlan.Modules.Events.Application;

using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <inheritdoc />
public sealed class GuestMembershipLinking(IEventsDbContext db) : IGuestMembershipLinking
{
    /// <summary>
    /// Empreinte du jeton d'invité. Doit rester identique au calcul de
    /// <see cref="JoinService"/>, qui la pose à l'adhésion : deux calculs différents ne
    /// se retrouveraient jamais, et aucune participation ne serait jamais rattachée.
    /// </summary>
    internal static string Empreinte(string valeur) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(valeur)));

    public async Task<int> LinkAsync(
        Guid userId,
        string guestToken,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(db);

        if (string.IsNullOrWhiteSpace(guestToken))
        {
            return 0;
        }

        var empreinte = Empreinte(guestToken);

        // IgnoreQueryFilters est indispensable, et sûr ici.
        //
        // Indispensable : le filtre global (RG-SEC-01) restreint les membres aux
        // événements du périmètre de l'appelant, or un compte qui vient d'être créé n'en
        // a aucun. Sans cela, la requête ne trouverait jamais rien.
        //
        // Sûr : le critère est l'empreinte du jeton d'invité, qui est elle-même la
        // preuve d'appartenance. Seul le porteur du jeton peut la produire, et le jeton
        // n'a été remis qu'à la personne qui a rejoint l'événement.
        var participations = await db.EventMembers
            .IgnoreQueryFilters()
            .Where(m => m.GuestSessionHash == empreinte
                     && m.UserId == null
                     && m.RemovedAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        if (participations.Count == 0)
        {
            // Un jeton périmé ou inconnu n'est pas une erreur : il ne doit pas empêcher
            // de créer un compte ni de se connecter.
            return 0;
        }

        var evenements = participations.Select(m => m.EventId).ToList();

        // Membres que le compte possède déjà sur ces événements : une conversion ne doit
        // jamais produire deux lignes pour une même personne.
        var deja = await db.EventMembers
            .IgnoreQueryFilters()
            .Where(m => m.UserId == userId && evenements.Contains(m.EventId))
            .Select(m => m.EventId)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var rattachees = 0;

        foreach (var participation in participations)
        {
            if (deja.Contains(participation.EventId))
            {
                // Le compte est déjà membre à un autre titre. La ligne d'invité est
                // retirée, jamais supprimée (RG-ROLE-03).
                //
                // TÂCHE OBLIGATOIRE DE B2 : dès que le module Expenses existe, les
                // contributions financières de cette ligne devront être réaffectées à la
                // ligne conservée, faute de quoi le critère d'acceptation EF-AUTH-11
                // « la dépense reste rattachée à lui » serait faux.
                participation.RemovedAt = DateTimeOffset.UtcNow;
                continue;
            }

            participation.UserId = userId;
            rattachees++;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return rattachees;
    }
}
