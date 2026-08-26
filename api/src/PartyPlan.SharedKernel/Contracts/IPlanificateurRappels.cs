namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Événement à venir, réduit à ce qu'un planificateur de rappels a besoin de savoir.
/// <para>
/// Ni nom, ni adresse, ni membres : un module qui planifie des rappels n'a pas à
/// connaître le contenu de la soirée (RG-ADM-01 dans l'esprit, règle 6 dans la lettre).
/// </para>
/// </summary>
public sealed record EvenementAVenir(
    Guid EventId,
    Guid OwnerUserId,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt)
{
    /// <summary>
    /// Fin effective. Un événement sans fin déclarée dure douze heures, comme partout
    /// ailleurs dans le domaine.
    /// </summary>
    public DateTimeOffset FinEffective => EndsAt ?? StartsAt.AddHours(12);
}

/// <summary>
/// Événements à venir ou tout juste terminés. Contrat public du module Events.
/// </summary>
public interface IEvenementsAVenir
{
    /// <summary>
    /// Événements dont le début est dans les <paramref name="horizon"/> à venir, plus
    /// ceux terminés depuis moins de <paramref name="retard"/> — <c>EF-NOT-06</c>
    /// notifie le lendemain, donc après la fin.
    /// </summary>
    Task<IReadOnlyList<EvenementAVenir>> ListerAsync(
        DateTimeOffset maintenant,
        TimeSpan horizon,
        TimeSpan retard,
        CancellationToken cancellationToken);
}

/// <summary>
/// Calcul des rappels temporels d'un événement.
/// <para>
/// Implémenté par le module qui détient la donnée : l'ordonnanceur ne sait pas ce qu'est
/// un article non attribué, et il ne doit pas l'apprendre (règle 6). Ajouter un rappel,
/// c'est ajouter une implémentation, pas toucher à l'ordonnanceur.
/// </para>
/// <para>
/// <b>Doit être idempotent.</b> L'ordonnanceur balaie toutes les minutes et rappellera
/// cette méthode indéfiniment sur le même événement. La déduplication est assurée par la
/// clé de <see cref="NotificationAEnvoyer"/> ; l'implémentation n'a pas à compter ce
/// qu'elle a déjà fait.
/// </para>
/// </summary>
public interface IPlanificateurRappels
{
    Task PlanifierAsync(
        EvenementAVenir evenement,
        DateTimeOffset maintenant,
        CancellationToken cancellationToken);
}
