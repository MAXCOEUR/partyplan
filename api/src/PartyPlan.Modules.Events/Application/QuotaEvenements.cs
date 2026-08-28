namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Quotas de la formule gratuite (RG-PRM-01, ADR 0008).
/// <para>
/// Les décisions sont des méthodes statiques pures, séparées des lectures : les
/// frontières exactes se testent alors sans base ni horloge. Les deux règles partagent la
/// lecture de la formule, d'où une unité unique plutôt que deux méthodes dispersées dans
/// EventService et JoinService.
/// </para>
/// <para>
/// <b>Pourquoi le cloisonnement est ignoré ici.</b> Les trois lectures appellent
/// <c>IgnoreQueryFilters</c>, ce que RG-SEC-01 interdit par défaut. Sans cela elles ne
/// verraient rien : le filtre restreint au périmètre de la requête courante, et les deux
/// appelants sont précisément des moments où l'appelant n'a pas encore accès à
/// l'événement — il le crée, ou il le rejoint. C'est le motif que suit déjà
/// <c>JoinService.TrouverAsync</c>.
/// </para>
/// <para>
/// L'entorse ne fuit rien, et c'est ce qui la rend acceptable. Le comptage d'événements
/// est borné à <c>m.UserId == userId</c>, donc aux seuls événements de l'appelant. Les
/// deux autres lectures ne renvoient qu'un nombre et un booléen, sur un événement dont le
/// jeton d'invitation ou le code court a déjà été présenté. Aucun nom, aucun montant,
/// aucun contenu ne traverse : c'est la ligne que tient <c>IEventStatistics</c> pour
/// RG-ADM-01 — des nombres, jamais du contenu.
/// </para>
/// <para>
/// Ces quotas bornent une offre commerciale. Ils ne protègent ni un cloisonnement ni un
/// calcul financier, et aucune garantie transactionnelle n'est tentée : deux écritures
/// concurrentes au bord de la borne peuvent la franchir d'une unité. RG-PRM-02 rend le cas
/// inoffensif puisque rien n'est jamais dégradé après coup, et un dépassement est déjà
/// toléré par conception après un transfert de propriété.
/// </para>
/// </summary>
public sealed class QuotaEvenements(
    IEventsDbContext db,
    IFormuleCompte formule,
    IClock clock)
{
    /// <summary>Événements possédés simultanément en formule gratuite.</summary>
    public const int EvenementsMaximum = 3;

    /// <summary>Membres actifs par événement en formule gratuite.</summary>
    public const int MembresMaximum = 20;

    public static readonly DomainError QuotaAtteint = DomainError.Forbidden(
        "plan.event_quota_reached",
        $"Tu organises déjà {EvenementsMaximum} soirées à venir, le maximum de la formule "
        + "gratuite. Attends la fin de l'une d'elles, quitte-la ou supprime-la — ou passe à "
        + "la formule payante.");

    public static readonly DomainError PlafondMembresAtteint = DomainError.Forbidden(
        "plan.member_limit_reached",
        $"Cette soirée a atteint {MembresMaximum} participants, le maximum de la formule "
        + "gratuite de son organisateur.");

    /// <summary>Décision de création. Pure : testable sans base.</summary>
    public static bool CreationAutorisee(int possedes, bool abonne) =>
        abonne || possedes < EvenementsMaximum;

    /// <summary>Décision d'adhésion. La formule est celle du propriétaire (EF-PRM-03).</summary>
    public static bool AdhesionAutorisee(int membresActifs, bool proprietaireAbonne) =>
        proprietaireAbonne || membresActifs < MembresMaximum;

    /// <summary>
    /// Événements possédés et encore actifs.
    /// <para>
    /// La propriété se lit sur <c>event_members.role</c> et non sur
    /// <c>events.created_by_user_id</c> : le premier suit les transferts
    /// (AttendanceService.TransfererProprieteAsync), le second reste au créateur
    /// historique. Compter le créateur débiterait le cédant d'un événement qu'il ne
    /// possède plus et n'en créditerait jamais le repreneur.
    /// </para>
    /// <para>
    /// La fin effective est évaluée en mémoire : elle dépend de <c>EffectiveEndsAt</c>,
    /// propriété calculée qu'EF Core ne traduit pas en SQL. Le volume est borné par le
    /// nombre d'événements d'une personne, comme dans ListerAsync.
    /// </para>
    /// </summary>
    public async Task<int> CompterPossedesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var bornes = await db.Events
            .AsNoTracking()
            .IgnoreQueryFilters()
            .Where(e => e.DeletedAt == null
                && e.Members.Any(m =>
                    m.UserId == userId
                    && m.Role == EventMemberRole.Owner
                    && m.RemovedAt == null))
            .Select(e => new { e.StartsAt, e.EndsAt })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return bornes.Count(b => (b.EndsAt ?? b.StartsAt + Event.ImplicitDuration) > maintenant);
    }

    /// <summary>Membres actifs d'un événement. Les accompagnants n'y entrent pas (RG-PRES-04).</summary>
    public Task<int> CompterMembresActifsAsync(Guid eventId, CancellationToken cancellationToken) =>
        db.EventMembers
            .AsNoTracking()
            .IgnoreQueryFilters()
            .CountAsync(m => m.EventId == eventId && m.RemovedAt == null, cancellationToken);

    /// <summary>
    /// Formule du propriétaire de l'événement.
    /// <para>
    /// Sans propriétaire identifiable — ligne historique sans compte — la formule est
    /// gratuite : mieux vaut refuser une vingt-et-unième adhésion que lever un plafond sur
    /// une donnée absente.
    /// </para>
    /// </summary>
    public async Task<bool> ProprietaireAbonneAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var proprietaire = await db.EventMembers
            .AsNoTracking()
            .IgnoreQueryFilters()
            .Where(m => m.EventId == eventId
                && m.Role == EventMemberRole.Owner
                && m.RemovedAt == null
                && m.UserId != null)
            .Select(m => m.UserId)
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        return proprietaire is { } userId
            && await formule.EstAbonneAsync(userId, cancellationToken).ConfigureAwait(false);
    }
}
