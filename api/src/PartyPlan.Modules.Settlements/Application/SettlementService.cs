namespace PartyPlan.Modules.Settlements.Application;

using System.Diagnostics;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Settlements.Domain;
using PartyPlan.Modules.Settlements.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Solde d'un membre, tel que l'interface l'affiche (EF-RMB-01).</summary>
public sealed record BalanceView(
    Guid MemberId,
    string DisplayName,
    string? AvatarUrl,
    decimal Amount);

/// <summary>Règlement proposé (EF-RMB-02), ou déjà effectué (EF-RMB-03).</summary>
public sealed record SettlementView(
    Guid? Id,
    Guid FromMemberId,
    string FromDisplayName,
    string? FromAvatarUrl,
    Guid ToMemberId,
    string ToDisplayName,
    string? ToAvatarUrl,
    decimal Amount,
    bool Done,
    bool InvolvesMe);

/// <summary>
/// Vue complète des remboursements.
/// <para>
/// <see cref="InvariantHolds"/> est faux lorsque la somme des soldes n'est pas nulle
/// (IV-02). L'interface le signale au lieu d'afficher des chiffres qu'on sait faux
/// (RG-RMB-04).
/// </para>
/// </summary>
public sealed record SettlementsPage(
    IReadOnlyList<BalanceView> Balances,
    IReadOnlyList<SettlementView> Proposed,
    IReadOnlyList<SettlementView> Done,
    decimal MyBalance,
    bool InvariantHolds);

/// <summary>Marquage d'un remboursement effectué (EF-RMB-03).</summary>
public sealed record MarkSettlementRequest(Guid FromMemberId, Guid ToMemberId, decimal Amount);

/// <summary>
/// Remboursements (EF-RMB-01 à EF-RMB-05).
/// <para>
/// Aucun solde n'est persisté (RG-RMB-02) : tout est recalculé à la demande depuis les
/// dépenses et les règlements effectués. Persister un solde créerait une seconde source
/// de vérité, et la moindre divergence serait invisible jusqu'au litige.
/// </para>
/// </summary>
public sealed class SettlementService(
    ISettlementsDbContext db,
    IExpenseLedger ledger,
    IEventMembership membership,
    IClock clock,
    IIdGenerator ids,
    ILogger<SettlementService> logger,
    IDiffusionEvenement diffusion,
    IJournalActivite journal)
    : ISettlementStatus
{
    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NotFound = DomainError.NotFound(
        "settlement.not_found",
        "Ce remboursement est introuvable.");

    public static readonly DomainError SameMember = DomainError.Validation(
        "settlement.same_member",
        "Un remboursement va d'un membre à un autre.");

    public static readonly DomainError AmountOutOfRange = DomainError.Validation(
        "settlement.amount_out_of_range",
        "Le montant d'un remboursement est strictement positif.");

    public static readonly DomainError UnknownMember = DomainError.Validation(
        "settlement.unknown_member",
        "Ce membre ne fait pas partie de l'événement.");

    /// <summary>
    /// Diffuse un règlement puis le changement de soldes, et renvoie le résultat.
    /// <para>
    /// Les deux messages partent ensemble : marquer un remboursement change les soldes
    /// de deux personnes, et le taire laisserait l'une réclamer ce que l'autre a déjà
    /// payé.
    /// </para>
    /// </summary>
    private async Task<Result<SettlementsPage>> DiffuserAsync(
        Guid eventId,
        string message,
        Result<SettlementsPage> resultat,
        CancellationToken cancellationToken)
    {
        if (resultat.IsSuccess)
        {
            await diffusion
                .PublierAsync(eventId, message, resultat.Value!, cancellationToken)
                .ConfigureAwait(false);

            await diffusion
                .PublierAsync(
                    eventId,
                    MessagesTempsReel.SoldesChanges,
                    new { eventId },
                    cancellationToken)
                .ConfigureAwait(false);
        }

        return resultat;
    }

    public async Task<Result<SettlementsPage>> ConsulterAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var etat = await CalculerAsync(eventId, cancellationToken).ConfigureAwait(false);
        var noms = await NomsAsync(eventId, etat.Soldes, cancellationToken).ConfigureAwait(false);

        var effectues = etat.Effectues
            .OrderByDescending(s => s.SettledAt)
            .Select(s => new SettlementView(
                s.Id,
                s.FromMemberId,
                Nom(noms, s.FromMemberId),
                Photo(noms, s.FromMemberId),
                s.ToMemberId,
                Nom(noms, s.ToMemberId),
                Photo(noms, s.ToMemberId),
                s.Amount,
                true,
                s.FromMemberId == moi.MemberId || s.ToMemberId == moi.MemberId))
            .ToList();

        return Result<SettlementsPage>.Success(new SettlementsPage(
            [
                .. etat.Soldes
                    .Where(s => s.Cents != 0)
                    .OrderByDescending(s => s.Cents)
                    .Select(s => new BalanceView(
                        s.MemberId,
                        Nom(noms, s.MemberId),
                        Photo(noms, s.MemberId),
                        s.Cents / 100m)),
            ],
            [
                // RG-CALC-01 : l'ordre est celui de l'émission, jamais un tri ultérieur.
                .. etat.Proposes.Select(r => new SettlementView(
                    null,
                    r.FromMemberId,
                    Nom(noms, r.FromMemberId),
                    Photo(noms, r.FromMemberId),
                    r.ToMemberId,
                    Nom(noms, r.ToMemberId),
                    Photo(noms, r.ToMemberId),
                    r.Cents / 100m,
                    false,
                    r.FromMemberId == moi.MemberId || r.ToMemberId == moi.MemberId)),
            ],
            effectues,
            etat.Soldes.FirstOrDefault(s => s.MemberId == moi.MemberId).Cents / 100m,
            etat.InvariantRespecte));
    }

    /// <summary>Marque un remboursement comme effectué (EF-RMB-03).</summary>
    public async Task<Result<SettlementsPage>> MarquerAsync(
        Guid eventId,
        MarkSettlementRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        if (requete.FromMemberId == requete.ToMemberId)
        {
            return SameMember;
        }

        if (requete.Amount <= 0m)
        {
            return AmountOutOfRange;
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);
        var connus = membres.Select(m => m.MemberId).ToHashSet();

        if (!connus.Contains(requete.FromMemberId) || !connus.Contains(requete.ToMemberId))
        {
            return UnknownMember;
        }

        db.Settlements.Add(new Settlement
        {
            Id = ids.NewId(),
            EventId = eventId,
            FromMemberId = requete.FromMemberId,
            ToMemberId = requete.ToMemberId,
            Amount = requete.Amount,
            SettledAt = clock.UtcNow,
            MarkedByMemberId = moi.MemberId,
        });

        // Les deux parties, et non l'auteur seul : une personne qui gère l'événement
        // peut marquer un remboursement entre deux autres, auquel cas ActorName ne dit
        // pas qui a réglé qui.
        journal.Consigner(
            eventId,
            moi.MemberId,
            moi.DisplayName,
            ActivityKinds.SettlementMarked,
            new
            {
                de = NomDe(membres, requete.FromMemberId),
                vers = NomDe(membres, requete.ToMemberId),
                montant = requete.Amount,
            });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        var page = await ConsulterAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ReglementMarque,
            page,
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Annule un marquage erroné (EF-RMB-04). L'annulation est elle-même horodatée : la
    /// ligne n'est jamais supprimée, sans quoi l'historique deviendrait inexplicable.
    /// </summary>
    public async Task<Result<SettlementsPage>> AnnulerAsync(
        Guid eventId,
        Guid settlementId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var reglement = await db.Settlements
            .FirstOrDefaultAsync(
                s => s.EventId == eventId && s.Id == settlementId && s.CancelledAt == null,
                cancellationToken)
            .ConfigureAwait(false);

        if (reglement is null)
        {
            return NotFound;
        }

        reglement.CancelledAt = clock.UtcNow;

        var parties = await membership.ListActiveAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        journal.Consigner(
            eventId,
            moi.MemberId,
            moi.DisplayName,
            ActivityKinds.SettlementCancelled,
            new
            {
                de = NomDe(parties, reglement.FromMemberId),
                vers = NomDe(parties, reglement.ToMemberId),
                montant = reglement.Amount,
            });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        var page = await ConsulterAsync(eventId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ReglementAnnule,
            page,
            cancellationToken).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task<bool> HasPendingAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var etat = await CalculerAsync(eventId, cancellationToken).ConfigureAwait(false);

        return etat.Soldes.Any(s => s.Cents != 0);
    }

    // --------------------------------------------------------------- outils ----

    /// <summary>
    /// Nom d'un membre au moment de l'action. Le fil le fige (RG-USR-04) : un
    /// changement de nom ultérieur ne doit pas réécrire qui devait quoi à qui.
    /// </summary>
    private static string NomDe(IReadOnlyList<EventMemberRef> membres, Guid memberId) =>
        membres.FirstOrDefault(m => m.MemberId == memberId)?.DisplayName ?? string.Empty;


    private async Task<(IReadOnlyList<Solde> Soldes,
                       IReadOnlyList<Reglement> Proposes,
                       List<Settlement> Effectues,
                       bool InvariantRespecte)>
        CalculerAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var comptes = await ledger.GetAsync(eventId, cancellationToken).ConfigureAwait(false);

        var effectues = await db.Settlements
            .Where(s => s.EventId == eventId && s.CancelledAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var soldes = Soldes.Calculer(
            [.. comptes.Select(c => new LigneDeCompte(c.MemberId, c.AdvancedCents, c.OwedCents))],
            [
                .. effectues.Select(s => new ReglementEffectue(
                    s.FromMemberId,
                    s.ToMemberId,
                    (long)decimal.Round(s.Amount * 100m, 0, MidpointRounding.ToEven))),
            ]);

        var respecte = Soldes.InvariantRespecte(soldes);

        if (!respecte)
        {
            // IV-02 rompu : les chiffres affichés sont faux. Journalisé en erreur et
            // signalé à l'interface, plutôt que présenté comme s'il n'y avait rien.
            logger.LogError(
                "IV-02 rompu sur l'événement {EventId} : somme des soldes = {Somme} centimes.",
                eventId,
                soldes.Sum(s => s.Cents));

            Debug.Assert(false, "IV-02 rompu.");
        }

        return (soldes, Soldes.Simplifier(soldes), effectues, respecte);
    }

    /// <summary>Nom d'un membre, avec un substitut pour un participant disparu.</summary>
    private static string Nom(Dictionary<Guid, EventMemberRef> membres, Guid memberId) =>
        membres.TryGetValue(memberId, out var membre) ? membre.DisplayName : "?";

    /// <summary>Photo d'un membre, ou <c>null</c> — l'écran affiche ses initiales.</summary>
    private static string? Photo(Dictionary<Guid, EventMemberRef> membres, Guid memberId) =>
        membres.TryGetValue(memberId, out var membre) ? membre.AvatarUrl : null;

    private async Task<Dictionary<Guid, EventMemberRef>> NomsAsync(
        Guid eventId,
        IReadOnlyList<Solde> soldes,
        CancellationToken cancellationToken)
    {
        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);
        var noms = membres.ToDictionary(m => m.MemberId);

        // Un membre exclu conserve ses lignes financières (RG-ROLE-03) mais ne figure
        // plus dans la liste : lui donner un nom générique vaut mieux qu'un « ? » sur un
        // écran d'argent. Sans photo, forcément : le compte n'est plus accessible d'ici.
        foreach (var solde in soldes.Where(s => !noms.ContainsKey(s.MemberId)))
        {
            noms[solde.MemberId] = new EventMemberRef(
                solde.MemberId,
                "Ancien participant",
                null,
                CountsAsPresent: false,
                CanManage: false);
        }

        return noms;
    }
}
