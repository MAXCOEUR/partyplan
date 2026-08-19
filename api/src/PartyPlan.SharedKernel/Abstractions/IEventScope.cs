namespace PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Périmètre d'événements accessible à l'appelant de la requête courante.
/// <para>
/// Support du cloisonnement RG-SEC-01 : le filtre est appliqué par le DbContext à
/// toute entité marquée <see cref="IEventScoped"/>, et non répété dans chaque requête
/// (RG-SEC-02). Un rôle plateforme ne l'élargit jamais (RG-ADM-01).
/// </para>
/// </summary>
public interface IEventScope
{
    /// <summary>
    /// Événements dont l'appelant est membre actif. Tableau vide pour un appelant
    /// anonyme : dans ce cas, aucune entité rattachée à un événement n'est visible.
    /// </summary>
    Guid[] AllowedEventIds { get; }

    /// <summary>Vrai lorsque le périmètre a été calculé pour la requête courante.</summary>
    bool IsPrimed { get; }

    /// <summary>Fixe le périmètre. Appelé une seule fois par requête.</summary>
    void Prime(IEnumerable<Guid> eventIds);

    /// <summary>
    /// Élargit temporairement le périmètre à un événement, le temps d'une opération
    /// d'adhésion : rejoindre un événement suppose de le lire avant d'en être membre
    /// (EF-INV-04). Portée volontairement explicite et locale.
    /// </summary>
    IDisposable AllowTemporarily(Guid eventId);
}
