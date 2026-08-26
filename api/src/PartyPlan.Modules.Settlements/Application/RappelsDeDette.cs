namespace PartyPlan.Modules.Settlements.Application;

using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Rappel du montant dû, le lendemain de l'événement (<c>EF-NOT-06</c>).
/// <para>
/// À chaque débiteur, avec <b>son</b> montant. Un rappel collectif obligerait chacun à
/// ouvrir l'application pour savoir s'il est concerné, ce qui est exactement le travail
/// que la notification doit épargner.
/// </para>
/// <para>
/// Les soldes viennent du calcul qui fait foi, celui qu'éprouve le jeu de référence du
/// §6.5. Recopier la formule ici la ferait diverger au premier ajustement.
/// </para>
/// </summary>
public sealed class RappelsDeDette(
    SettlementService reglements,
    IEventMembership membership,
    IFileNotifications notifications) : IPlanificateurRappels
{
    /// <summary>
    /// Délai après la fin. Le lendemain, et non le soir même : personne ne veut être
    /// relancé sur ses comptes pendant qu'il range.
    /// </summary>
    private static readonly TimeSpan Apres = TimeSpan.FromDays(1);

    /// <summary>Au-delà, on cesse de relancer — la passe suivante s'en chargerait sinon
    /// indéfiniment, la fenêtre de l'ordonnanceur restant ouverte deux jours.</summary>
    private static readonly TimeSpan Fenetre = TimeSpan.FromHours(6);

    public async Task PlanifierAsync(
        EvenementAVenir evenement,
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(evenement);

        var echeance = evenement.FinEffective + Apres;

        if (maintenant < echeance || maintenant > echeance + Fenetre)
        {
            return;
        }

        var (soldes, _, _, _) = await reglements
            .CalculerAsync(evenement.EventId, cancellationToken)
            .ConfigureAwait(false);

        // Un solde négatif est une dette. Les créanciers ne sont pas relancés : ils
        // n'ont rien à faire, et la relance appartient au débiteur.
        var debiteurs = soldes.Where(s => s.Cents < 0).ToList();

        if (debiteurs.Count == 0)
        {
            return;
        }

        var membres = await membership
            .ListActiveAsync(evenement.EventId, cancellationToken)
            .ConfigureAwait(false);

        foreach (var solde in debiteurs)
        {
            // Une ligne historique sans compte ne reçoit rien : il n'y a personne à
            // joindre. C'est aussi la raison pour laquelle UserId est nullable sur
            // event_members (règle 7).
            var compte = membres
                .FirstOrDefault(m => m.MemberId == solde.MemberId)?.UserId;

            if (compte is null)
            {
                continue;
            }

            notifications.Enfiler(new NotificationAEnvoyer(
                compte,
                evenement.EventId,
                NotificationCategories.BalanceDue,
                "Il reste des comptes à solder",
                $"Tu dois {Montant(-solde.Cents)} pour cette soirée.",
                $"/events/{evenement.EventId}/reglements",
                maintenant,
                $"{evenement.EventId}:{NotificationCategories.BalanceDue}:{solde.MemberId}:lendemain"));
        }
    }

    /// <summary>
    /// Montant en euros, depuis les centimes entiers du domaine. La conversion a lieu à
    /// l'affichage seul : le calcul reste en centimes (§6.1).
    /// </summary>
    private static string Montant(long cents) =>
        $"{cents / 100},{cents % 100:00} €";
}
