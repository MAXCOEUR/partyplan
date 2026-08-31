namespace PartyPlan.Modules.Expenses.Application;

using System.Globalization;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Expenses.Domain;
using PartyPlan.Modules.Expenses.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Mode de constitution de l'assiette (EF-DEP-02).</summary>
public enum SplitMode
{
    /// <summary>Tous les membres comptés présents au moment de la création.</summary>
    AllPresent,

    /// <summary>Sélection explicite, à parts égales.</summary>
    Selection,

    /// <summary>Sélection explicite, avec des parts personnalisées.</summary>
    Custom,
}

/// <summary>Participant à une dépense, tel que l'interface l'affiche.</summary>
public sealed record ExpenseShareView(
    Guid MemberId,
    string DisplayName,
    int Share,
    decimal Amount);

/// <summary>Dépense dans la liste (EF-DEP-04).</summary>
public sealed record ExpenseListItem(
    Guid Id,
    string Label,
    decimal Amount,
    Guid PaidByMemberId,
    string PaidByDisplayName,
    DateTimeOffset SpentAt,
    int ParticipantCount,
    bool FromShoppingItem);

/// <summary>Détail d'une dépense (EF-DEP-05).</summary>
public sealed record ExpenseDetail(
    Guid Id,
    string Label,
    decimal Amount,
    Guid PaidByMemberId,
    string PaidByDisplayName,
    DateTimeOffset SpentAt,
    bool FromShoppingItem,
    int RevisionCount,
    IReadOnlyList<ExpenseShareView> Shares);

/// <summary>Totaux affichés en tête de liste.</summary>
public sealed record ExpensesPage(decimal Total, decimal MyShare, IReadOnlyList<ExpenseListItem> Items);

/// <summary>Part personnalisée demandée par l'appelant.</summary>
public sealed record ShareRequest(Guid MemberId, int Share);

/// <summary>Création ou modification d'une dépense (EF-DEP-01, EF-DEP-03).</summary>
public sealed record ExpenseRequest(
    string Label,
    decimal Amount,
    Guid? PaidByMemberId,
    DateTimeOffset? SpentAt,
    string? Mode,
    IReadOnlyList<ShareRequest>? Shares);

/// <summary>
/// Dépenses (EF-DEP-01 à EF-DEP-05).
/// <para>
/// L'assiette est figée à la création (RG-DEP-02) : les parts attribuées sont calculées
/// une fois et persistées. Une arrivée tardive ne redistribue pas rétroactivement une
/// dépense déjà payée — ce serait la meilleure façon de rendre les soldes
/// incompréhensibles.
/// </para>
/// </summary>
public sealed class ExpenseService(
    IExpensesDbContext db,
    IEventMembership membership,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IJournalActivite journal,
    IFileNotifications notifications,
    IReveilNotifications reveil)
    : IExpenseLedger, IExpenseFromPurchase
{
    public static readonly DomainError NotFound = DomainError.NotFound(
        "expense.not_found",
        "Cette dépense est introuvable.");

    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NotMine = DomainError.Rule(
        "expense.not_mine",
        "Seule la personne qui a payé, ou l'organisateur, modifie cette dépense.");

    public static readonly DomainError LabelRequired = DomainError.Validation(
        "expense.label_required",
        "Donne un libellé à la dépense.");

    public static readonly DomainError AmountOutOfRange = DomainError.Validation(
        "expense.amount_out_of_range",
        $"Le montant doit être supérieur à 0 et au plus {Expense.MaxAmount:0.00} €.");

    public static readonly DomainError UnknownMode = DomainError.Validation(
        "expense.unknown_mode",
        "Mode d'assiette inconnu. Valeurs acceptées : AllPresent, Selection, Custom.");

    public static readonly DomainError EmptySplit = DomainError.Validation(
        "expense.empty_split",
        "Une dépense a au moins un participant.");

    public static readonly DomainError UnknownParticipant = DomainError.Validation(
        "expense.unknown_participant",
        "Un participant ne fait pas partie de l'événement.");

    public static readonly DomainError ShareOutOfRange = DomainError.Validation(
        "expense.share_out_of_range",
        "Une part est un entier strictement positif.");

    public static readonly DomainError FromShoppingItem = DomainError.Rule(
        "expense.from_shopping_item",
        "Cette dépense vient d'un article de courses : modifie le prix payé sur l'article.");

    // ------------------------------------------------------------- lecture ----

    /// <summary>
    /// Diffuse une dépense et le changement de soldes qu'elle entraîne, puis renvoie le
    /// résultat tel quel.
    /// <para>
    /// Les deux messages vont ensemble et ne se séparent pas : une dépense change
    /// forcément les soldes, et ne diffuser que la dépense laisserait l'écran des
    /// remboursements faux jusqu'à sa prochaine ouverture. C'est précisément le genre
    /// d'écart qu'on ne remarque qu'en réclamant de l'argent à quelqu'un qui a déjà payé.
    /// </para>
    /// </summary>
    private async Task<Result<ExpenseDetail>> DiffuserAsync(
        Guid eventId,
        string message,
        Result<ExpenseDetail> resultat,
        CancellationToken cancellationToken)
    {
        if (resultat.IsSuccess)
        {
            await diffusion
                .PublierAsync(eventId, message, resultat.Value!, cancellationToken)
                .ConfigureAwait(false);

            await DiffuserSoldesAsync(eventId, cancellationToken).ConfigureAwait(false);
        }

        return resultat;
    }

    /// <summary>
    /// Signale que les soldes ont changé, sans les envoyer.
    /// <para>
    /// Le tableau complet des soldes de tous les membres dans chaque message le rendrait
    /// volumineux pour rien : le client relit (RG-RT-02, précision du 25/08/2026).
    /// </para>
    /// </summary>
    private Task DiffuserSoldesAsync(Guid eventId, CancellationToken cancellationToken) =>
        diffusion.PublierAsync(
            eventId,
            MessagesTempsReel.SoldesChanges,
            new { eventId },
            cancellationToken);

    public async Task<Result<ExpensesPage>> ListerAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var membres = await NomsAsync(eventId, cancellationToken).ConfigureAwait(false);

        var depenses = await db.Expenses
            .Where(e => e.EventId == eventId)
            .Include(e => e.Participants)
            .OrderByDescending(e => e.SpentAt)
            .ThenByDescending(e => e.CreatedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var maPart = depenses
            .SelectMany(e => e.Participants)
            .Where(p => p.MemberId == moi.MemberId)
            .Sum(p => (long)p.AmountCents);

        return Result<ExpensesPage>.Success(new ExpensesPage(
            depenses.Sum(e => e.Amount),
            maPart / 100m,
            [
                .. depenses.Select(e => new ExpenseListItem(
                    e.Id,
                    e.Label,
                    e.Amount,
                    e.PaidByMemberId,
                    membres.GetValueOrDefault(e.PaidByMemberId, "?"),
                    e.SpentAt,
                    e.Participants.Count,
                    e.ShoppingItemId is not null)),
            ]));
    }

    public async Task<Result<ExpenseDetail>> DetailAsync(
        Guid eventId,
        Guid expenseId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var depense = await TrouverAsync(eventId, expenseId, cancellationToken).ConfigureAwait(false);
        if (depense is null)
        {
            return NotFound;
        }

        var membres = await NomsAsync(eventId, cancellationToken).ConfigureAwait(false);

        return Result<ExpenseDetail>.Success(new ExpenseDetail(
            depense.Id,
            depense.Label,
            depense.Amount,
            depense.PaidByMemberId,
            membres.GetValueOrDefault(depense.PaidByMemberId, "?"),
            depense.SpentAt,
            depense.ShoppingItemId is not null,
            depense.Revisions.Count,
            [
                .. depense.Participants
                    .OrderBy(p => p.MemberId)
                    .Select(p => new ExpenseShareView(
                        p.MemberId,
                        membres.GetValueOrDefault(p.MemberId, "?"),
                        p.Share,
                        p.AmountCents / 100m)),
            ]));
    }

    // ------------------------------------------------------------ écriture ----

    public async Task<Result<ExpenseDetail>> CreerAsync(
        Guid eventId,
        ExpenseRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);

        var assiette = ConstruireAssiette(requete, membres, out var erreur);
        if (erreur is not null)
        {
            return erreur;
        }

        var validation = Valider(requete);
        if (validation is not null)
        {
            return validation;
        }

        // Le payeur est celui qui est déclaré, ou l'appelant à défaut. Il peut ne pas
        // figurer dans l'assiette (RG-DEP-03) : offrir une tournée est un cas normal.
        var payeur = requete.PaidByMemberId ?? moi.MemberId;
        if (membres.All(m => m.MemberId != payeur))
        {
            return UnknownParticipant;
        }

        var depense = new Expense
        {
            Id = ids.NewId(),
            EventId = eventId,
            Label = requete.Label.Trim(),
            Amount = requete.Amount,
            PaidByMemberId = payeur,
            SpentAt = requete.SpentAt ?? clock.UtcNow,
            CreatedByMemberId = moi.MemberId,
            CreatedAt = clock.UtcNow,
            UpdatedAt = clock.UtcNow,
        };

        Repartir(depense, assiette!);

        db.Expenses.Add(depense);

        journal.Consigner(
            eventId,
            moi.MemberId,
            moi.DisplayName,
            ActivityKinds.ExpenseCreated,
            new { libelle = depense.Label, montant = depense.Amount });

        // Seuls les porteurs d'une part sont notifiés : être averti d'une dépense dont
        // on ne porte aucune part est du bruit, et le bruit fait couper la catégorie
        // entière. Jamais le payeur, jamais un membre sans compte.
        var payeurDisplayName = membres.First(m => m.MemberId == payeur).DisplayName;
        var montant = Formater(depense.Amount);

        foreach (var part in depense.Participants)
        {
            var membre = membres.FirstOrDefault(m => m.MemberId == part.MemberId);

            if (membre is null || membre.MemberId == moi.MemberId || membre.UserId is not { } compte)
            {
                continue;
            }

            notifications.Enfiler(new NotificationAEnvoyer(
                compte,
                eventId,
                NotificationCategories.ExpenseNew,
                "Nouvelle dépense",
                $"{payeurDisplayName} a ajouté {depense.Label} pour {montant} €.",
                $"/events/{eventId}",
                clock.UtcNow,
                $"{eventId}:{NotificationCategories.ExpenseNew}:{compte}:{depense.Id}"));
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Après validation, jamais avant : une transaction en échec ne doit réveiller
        // personne pour une dépense qui n'existera pas.
        reveil.Reveiller();

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        var creee = await DetailAsync(eventId, depense.Id, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.DepenseCreee,
            creee,
            cancellationToken).ConfigureAwait(false);
    }

    public async Task<Result<ExpenseDetail>> ModifierAsync(
        Guid eventId,
        Guid expenseId,
        ExpenseRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var depense = await TrouverAsync(eventId, expenseId, cancellationToken).ConfigureAwait(false);
        if (depense is null)
        {
            return NotFound;
        }

        if (depense.ShoppingItemId is not null)
        {
            return FromShoppingItem;
        }

        // Corriger la dépense d'autrui change ce qu'il a avancé, donc ce que chacun lui
        // doit : c'est le geste qui rend les comptes contestables. Une personne qui gère
        // l'événement en est dispensée — elle arbitre, et sans elle l'erreur d'un invité
        // parti depuis resterait inscrite pour toujours.
        if (depense.PaidByMemberId != moi.MemberId && !moi.CanManage)
        {
            return NotMine;
        }

        var validation = Valider(requete);
        if (validation is not null)
        {
            return validation;
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);
        var assiette = ConstruireAssiette(requete, membres, out var erreur);
        if (erreur is not null)
        {
            return erreur;
        }

        // RG-DEP-04 : l'état précédent est conservé avant toute modification. C'est ce
        // qui permet de trancher un litige sur un montant, et la table est en ajout seul.
        db.ExpenseRevisions.Add(new ExpenseRevision
        {
            Id = ids.NewId(),
            ExpenseId = depense.Id,
            EditedByMemberId = moi.MemberId,
            PreviousAmount = depense.Amount,
            PreviousParticipants = JsonSerializer.Serialize(
                depense.Participants.Select(p => new { p.MemberId, p.Share, p.AmountCents })),
            CreatedAt = clock.UtcNow,
        });

        // Lu avant écrasement : après, « combien c'était avant » n'est plus lisible
        // sans ouvrir la table des révisions.
        var ancienMontant = depense.Amount;

        depense.Label = requete.Label.Trim();
        depense.Amount = requete.Amount;
        depense.PaidByMemberId = requete.PaidByMemberId ?? depense.PaidByMemberId;
        depense.SpentAt = requete.SpentAt ?? depense.SpentAt;
        depense.UpdatedAt = clock.UtcNow;

        depense.Participants.Clear();
        Repartir(depense, assiette!);

        journal.Consigner(
            eventId,
            moi.MemberId,
            moi.DisplayName,
            ActivityKinds.ExpenseUpdated,
            new { libelle = depense.Label, ancienMontant, montant = depense.Amount });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        var modifiee = await DetailAsync(eventId, expenseId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.DepenseModifiee,
            modifiee,
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Suppression logique (RG-DEP-05). La ligne subsiste et les soldes sont recalculés :
    /// effacer réellement une dépense rendrait impossible d'expliquer un solde passé.
    /// </summary>
    public async Task<Result> SupprimerAsync(
        Guid eventId,
        Guid expenseId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var depense = await TrouverAsync(eventId, expenseId, cancellationToken).ConfigureAwait(false);
        if (depense is null)
        {
            return NotFound;
        }

        if (depense.ShoppingItemId is not null)
        {
            return FromShoppingItem;
        }

        if (depense.PaidByMemberId != moi.MemberId && !moi.CanManage)
        {
            return NotMine;
        }

        depense.DeletedAt = clock.UtcNow;

        journal.Consigner(
            eventId,
            moi.MemberId,
            moi.DisplayName,
            ActivityKinds.ExpenseDeleted,
            new { libelle = depense.Label, montant = depense.Amount });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        // Une suppression change les soldes comme une création : les deux messages
        // partent ensemble.
        await diffusion
            .PublierAsync(
                eventId,
                MessagesTempsReel.DepenseSupprimee,
                new { expenseId },
                cancellationToken)
            .ConfigureAwait(false);

        await DiffuserSoldesAsync(eventId, cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    // ------------------------------------------------- contrats publics ----

    /// <inheritdoc />
    public async Task<IReadOnlyList<LedgerLine>> GetAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var depenses = await db.Expenses
            .Where(e => e.EventId == eventId)
            .Include(e => e.Participants)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var avance = new Dictionary<Guid, long>();
        var du = new Dictionary<Guid, long>();

        foreach (var depense in depenses)
        {
            // Le montant avancé est repris de la somme des parts, et non du montant
            // décimal : les deux sont égaux par l'invariant IV-01, et passer par les
            // centimes évite toute conversion à la frontière.
            avance[depense.PaidByMemberId] =
                avance.GetValueOrDefault(depense.PaidByMemberId)
                + depense.Participants.Sum(p => (long)p.AmountCents);

            foreach (var part in depense.Participants)
            {
                du[part.MemberId] = du.GetValueOrDefault(part.MemberId) + part.AmountCents;
            }
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);

        // Les membres exclus conservent leurs lignes financières (RG-ROLE-03) : ils
        // doivent apparaître au compte, sinon leur dette disparaîtrait avec eux.
        var identifiants = membres.Select(m => m.MemberId)
            .Concat(avance.Keys)
            .Concat(du.Keys)
            .Distinct()
            .OrderBy(id => id);

        return
        [
            .. identifiants.Select(id => new LedgerLine(
                id,
                avance.GetValueOrDefault(id),
                du.GetValueOrDefault(id))),
        ];
    }

    /// <inheritdoc />
    public async Task<Guid> UpsertAsync(
        Guid eventId,
        Guid shoppingItemId,
        string label,
        decimal amount,
        Guid paidByMemberId,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(label);

        var existante = await db.Expenses
            .Include(e => e.Participants)
            .FirstOrDefaultAsync(
                e => e.EventId == eventId && e.ShoppingItemId == shoppingItemId,
                cancellationToken)
            .ConfigureAwait(false);

        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);

        // Un achat profite à ceux qui sont là : l'assiette par défaut est celle des
        // présents, comme pour une dépense saisie à la main.
        var assiette = membres
            .Where(m => m.CountsAsPresent)
            .Select(m => (m.MemberId, 1))
            .ToList();

        if (assiette.Count == 0)
        {
            assiette = [.. membres.Select(m => (m.MemberId, 1))];
        }

        if (existante is null)
        {
            existante = new Expense
            {
                Id = ids.NewId(),
                EventId = eventId,
                ShoppingItemId = shoppingItemId,
                PaidByMemberId = paidByMemberId,
                SpentAt = clock.UtcNow,
                CreatedByMemberId = paidByMemberId,
                CreatedAt = clock.UtcNow,
            };

            db.Expenses.Add(existante);
        }
        else
        {
            existante.Participants.Clear();
            existante.DeletedAt = null;
        }

        existante.Label = label.Trim();
        existante.Amount = amount;
        existante.PaidByMemberId = paidByMemberId;
        existante.UpdatedAt = clock.UtcNow;

        Repartir(existante, assiette);

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return existante.Id;
    }

    /// <inheritdoc />
    public async Task RemoveForItemAsync(
        Guid eventId,
        Guid shoppingItemId,
        CancellationToken cancellationToken)
    {
        var depense = await db.Expenses
            .FirstOrDefaultAsync(
                e => e.EventId == eventId && e.ShoppingItemId == shoppingItemId,
                cancellationToken)
            .ConfigureAwait(false);

        if (depense is null)
        {
            return;
        }

        depense.DeletedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    /// <inheritdoc />
    public Task<bool> ExistsForItemAsync(
        Guid eventId,
        Guid shoppingItemId,
        CancellationToken cancellationToken) =>
        db.Expenses.AnyAsync(
            e => e.EventId == eventId && e.ShoppingItemId == shoppingItemId,
            cancellationToken);

    // --------------------------------------------------------------- outils ----

    private Task<Expense?> TrouverAsync(
        Guid eventId,
        Guid expenseId,
        CancellationToken cancellationToken) =>
        db.Expenses
            .Include(e => e.Participants)
            .Include(e => e.Revisions)
            // Deux collections dans une même requête produiraient un produit cartésien.
            // Le projet traite l'avertissement d'EF comme une erreur, à raison : sur une
            // dépense à dix participants et vingt révisions, la requête unique renverrait
            // deux cents lignes pour en reconstituer trente.
            .AsSplitQuery()
            .FirstOrDefaultAsync(e => e.EventId == eventId && e.Id == expenseId, cancellationToken);

    private async Task<Dictionary<Guid, string>> NomsAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);

        return membres.ToDictionary(m => m.MemberId, m => m.DisplayName);
    }

    private static DomainError? Valider(ExpenseRequest requete)
    {
        if (string.IsNullOrWhiteSpace(requete.Label) || requete.Label.Trim().Length > 160)
        {
            return LabelRequired;
        }

        // RG-DEP-01 : strictement positif et plafonné. Le plafond n'est pas décoratif —
        // il rend impossible qu'une faute de frappe fasse dérailler tous les soldes.
        return requete.Amount <= 0m || requete.Amount > Expense.MaxAmount
            ? AmountOutOfRange
            : null;
    }

    private static List<(Guid MemberId, int Share)>? ConstruireAssiette(
        ExpenseRequest requete,
        IReadOnlyList<EventMemberRef> membres,
        out DomainError? erreur)
    {
        erreur = null;

        var mode = requete.Mode is null
            ? SplitMode.AllPresent
            : Enum.TryParse<SplitMode>(requete.Mode, out var analyse)
                ? analyse
                : (SplitMode?)null;

        if (mode is null)
        {
            erreur = UnknownMode;
            return null;
        }

        if (mode == SplitMode.AllPresent)
        {
            // RG-PRES-02 : « arrive plus tard » et « part plus tôt » comptent comme
            // présents. La règle est portée par le contrat, pas réécrite ici.
            var presents = membres.Where(m => m.CountsAsPresent).ToList();

            if (presents.Count == 0)
            {
                erreur = EmptySplit;
                return null;
            }

            return [.. presents.Select(m => (m.MemberId, 1))];
        }

        var demandes = requete.Shares ?? [];

        if (demandes.Count == 0)
        {
            erreur = EmptySplit;
            return null;
        }

        var connus = membres.Select(m => m.MemberId).ToHashSet();

        foreach (var demande in demandes)
        {
            if (!connus.Contains(demande.MemberId))
            {
                erreur = UnknownParticipant;
                return null;
            }

            // En mode Selection les parts fournies sont ignorées : la sélection est à
            // parts égales par définition. Seul le mode Custom les honore.
            if (mode == SplitMode.Custom && demande.Share <= 0)
            {
                erreur = ShareOutOfRange;
                return null;
            }
        }

        return
        [
            .. demandes
                .DistinctBy(d => d.MemberId)
                .Select(d => (d.MemberId, mode == SplitMode.Custom ? d.Share : 1)),
        ];
    }

    /// <summary>
    /// Applique la répartition du §6.2 et fige les parts attribuées.
    /// <para>
    /// Le montant est converti en centimes une seule fois, par arrondi bancaire au
    /// centime le plus proche. Toute la suite du calcul reste entière.
    /// </para>
    /// </summary>
    private static void Repartir(Expense depense, List<(Guid MemberId, int Share)> assiette)
    {
        var cents = (int)decimal.Round(depense.Amount * 100m, 0, MidpointRounding.ToEven);

        foreach (var part in Repartition.Repartir(cents, assiette))
        {
            depense.Participants.Add(new ExpenseParticipant
            {
                ExpenseId = depense.Id,
                MemberId = part.MemberId,
                Share = assiette.First(a => a.MemberId == part.MemberId).Share,
                AmountCents = part.Cents,
            });
        }
    }

    /// <summary>Montant formaté pour un message, toujours en français.</summary>
    internal static string Formater(decimal montant) =>
        montant.ToString("0.00", CultureInfo.GetCultureInfo("fr-FR"));
}
