namespace PartyPlan.Modules.Shopping.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Shopping.Domain;
using PartyPlan.Modules.Shopping.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Article de la liste, tel que l'interface l'affiche.</summary>
public sealed record ShoppingItemView(
    Guid Id,
    string Name,
    decimal Quantity,
    string? Unit,
    string Category,
    Guid? AssignedMemberId,
    string? AssignedDisplayName,
    string? AssignedAvatarUrl,
    bool AssignedToMe,
    bool IsPurchased,
    decimal? PurchasedQuantity,
    decimal RemainingQuantity,
    decimal? EstimatedPrice,
    decimal? ActualPrice,
    string? Note);

/// <summary>Avancement de la liste (EF-CRS-09).</summary>
public sealed record ShoppingProgress(int Total, int Claimed, int Purchased);

/// <summary>Liste de courses complète.</summary>
public sealed record ShoppingList(ShoppingProgress Progress, IReadOnlyList<ShoppingItemView> Items);

/// <summary>Création ou modification d'un article (EF-CRS-01, EF-CRS-08).</summary>
public sealed record ShoppingItemRequest(
    string Name,
    decimal? Quantity,
    string? Unit,
    string? Category,
    decimal? EstimatedPrice,
    string? Note);

/// <summary>Déclaration d'achat (EF-CRS-05, EF-CRS-06).</summary>
public sealed record PurchaseRequest(decimal? PurchasedQuantity, decimal? ActualPrice);

/// <summary>
/// Liste de courses (EF-CRS-01 à EF-CRS-10).
/// <para>
/// L'attribution est unique et contrôlée côté serveur (RG-CRS-01) : deux personnes qui
/// s'attribuent le même article au même instant, c'est le cas normal d'une liste
/// partagée, pas un cas limite.
/// </para>
/// </summary>
public sealed class ShoppingService(
    IShoppingDbContext db,
    IEventMembership membership,
    IExpenseFromPurchase depenses,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IJournalActivite journal)
{
    public static readonly DomainError EventNotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NotFound = DomainError.NotFound(
        "shopping.item_not_found",
        "Cet article est introuvable.");

    public static readonly DomainError NameRequired = DomainError.Validation(
        "shopping.name_required",
        "Donne un nom à l'article.");

    public static readonly DomainError QuantityOutOfRange = DomainError.Validation(
        "shopping.quantity_out_of_range",
        "La quantité est strictement positive.");

    public static readonly DomainError UnknownCategory = DomainError.Validation(
        "shopping.unknown_category",
        "Catégorie inconnue. Valeurs acceptées : Drinks, Food, Supplies, Other.");

    public static readonly DomainError AlreadyClaimed = DomainError.Conflict(
        "shopping.already_claimed",
        "Quelqu'un vient de s'attribuer cet article.");

    public static readonly DomainError NotClaimedByMe = DomainError.Rule(
        "shopping.not_claimed_by_me",
        "Cet article est attribué à quelqu'un d'autre.");

    public static readonly DomainError HasExpense = DomainError.Rule(
        "shopping.has_expense",
        "Une dépense est rattachée à cet article : retire d'abord le prix payé.");

    public static readonly DomainError PriceOutOfRange = DomainError.Validation(
        "shopping.price_out_of_range",
        "Le prix payé est strictement positif.");

    public async Task<Result<ShoppingList>> ListerAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);
        var noms = membres.ToDictionary(m => m.MemberId);

        var articles = await db.ShoppingItems
            .Where(i => i.EventId == eventId)
            .OrderBy(i => i.Category)
            .ThenBy(i => i.Position)
            .ThenBy(i => i.CreatedAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return Result<ShoppingList>.Success(new ShoppingList(
            new ShoppingProgress(
                articles.Count,
                articles.Count(i => i.IsClaimed),
                articles.Count(i => i.IsPurchased)),
            [.. articles.Select(i => Vue(i, moi.MemberId, noms))]));
    }

    public async Task<Result<ShoppingItemView>> AjouterAsync(
        Guid eventId,
        ShoppingItemRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return EventNotFound;
        }

        var validation = Valider(requete, out var categorie);
        if (validation is not null)
        {
            return validation;
        }

        var position = await db.ShoppingItems
            .Where(i => i.EventId == eventId)
            .CountAsync(cancellationToken)
            .ConfigureAwait(false);

        var article = new ShoppingItem
        {
            Id = ids.NewId(),
            EventId = eventId,
            Name = requete.Name.Trim(),
            Quantity = requete.Quantity ?? 1m,
            Unit = string.IsNullOrWhiteSpace(requete.Unit) ? null : requete.Unit.Trim(),
            Category = categorie,
            EstimatedPrice = requete.EstimatedPrice,
            Note = string.IsNullOrWhiteSpace(requete.Note) ? null : requete.Note.Trim(),
            Position = position,
            CreatedByMemberId = moi.MemberId,
            CreatedAt = clock.UtcNow,
            UpdatedAt = clock.UtcNow,
        };

        db.ShoppingItems.Add(article);

        journal.Consigner(
            eventId,
            moi.MemberId,
            moi.DisplayName,
            ActivityKinds.ItemCreated,
            new { libelle = article.Name });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var ajoute = await RelireAsync(eventId, article.Id, moi.MemberId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ArticleCree,
            ajoute,
            cancellationToken).ConfigureAwait(false);
    }

    public async Task<Result<ShoppingItemView>> ModifierAsync(
        Guid eventId,
        Guid itemId,
        ShoppingItemRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var contexte = await ContexteAsync(eventId, itemId, cancellationToken).ConfigureAwait(false);
        if (contexte.Erreur is not null)
        {
            return contexte.Erreur;
        }

        var validation = Valider(requete, out var categorie);
        if (validation is not null)
        {
            return validation;
        }

        var article = contexte.Article!;
        article.Name = requete.Name.Trim();
        article.Quantity = requete.Quantity ?? article.Quantity;
        article.Unit = string.IsNullOrWhiteSpace(requete.Unit) ? null : requete.Unit.Trim();
        article.Category = categorie;
        article.EstimatedPrice = requete.EstimatedPrice;
        article.Note = string.IsNullOrWhiteSpace(requete.Note) ? null : requete.Note.Trim();
        article.UpdatedAt = clock.UtcNow;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ArticleModifie,
            Result<ShoppingItemView>.Success(Vue(
                article,
                contexte.MoiId,
                await NomsAsync(eventId, cancellationToken).ConfigureAwait(false))),
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Supprime un article. Refusé tant qu'une dépense y est rattachée (EF-CRS-08) :
    /// supprimer l'article ferait disparaître une dépense réellement engagée.
    /// </summary>
    public async Task<Result> SupprimerAsync(
        Guid eventId,
        Guid itemId,
        CancellationToken cancellationToken)
    {
        var contexte = await ContexteAsync(eventId, itemId, cancellationToken).ConfigureAwait(false);
        if (contexte.Erreur is not null)
        {
            return contexte.Erreur;
        }

        if (await depenses.ExistsForItemAsync(eventId, itemId, cancellationToken).ConfigureAwait(false))
        {
            return HasExpense;
        }

        contexte.Article!.DeletedAt = clock.UtcNow;

        journal.Consigner(
            eventId,
            contexte.MoiId,
            contexte.MonNom,
            ActivityKinds.ItemDeleted,
            new { libelle = contexte.Article.Name });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Pas d'état : l'article a quitté la liste, son identifiant suffit à savoir
        // quoi retirer.
        await diffusion
            .PublierAsync(
                eventId,
                MessagesTempsReel.ArticleSupprime,
                new { itemId },
                cancellationToken)
            .ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// S'attribue un article (EF-CRS-03).
    /// <para>
    /// RG-CRS-01 : l'attribution est unique. Le contrôle se fait en écriture
    /// conditionnelle côté base — vérifier puis écrire laisserait une fenêtre pendant
    /// laquelle deux personnes réussiraient toutes les deux.
    /// </para>
    /// </summary>
    public async Task<Result<ShoppingItemView>> AttribuerAsync(
        Guid eventId,
        Guid itemId,
        CancellationToken cancellationToken)
    {
        var contexte = await ContexteAsync(eventId, itemId, cancellationToken).ConfigureAwait(false);
        if (contexte.Erreur is not null)
        {
            return contexte.Erreur;
        }

        var lignes = await db.ShoppingItems
            .Where(i => i.EventId == eventId && i.Id == itemId && i.AssignedMemberId == null)
            .ExecuteUpdateAsync(
                mise => mise
                    .SetProperty(i => i.AssignedMemberId, contexte.MoiId)
                    .SetProperty(i => i.AssignedAt, clock.UtcNow)
                    .SetProperty(i => i.UpdatedAt, clock.UtcNow),
                cancellationToken)
            .ConfigureAwait(false);

        if (lignes == 0)
        {
            // Zéro ligne mise à jour : quelqu'un a été plus rapide. Le message le dit,
            // plutôt que de laisser croire à une panne.
            return contexte.Article!.AssignedMemberId == contexte.MoiId
                ? await RelireAsync(eventId, itemId, contexte.MoiId, cancellationToken)
                    .ConfigureAwait(false)
                : AlreadyClaimed;
        }

        // L'attribution passe par une écriture conditionnelle, déjà validée à ce
        // point : la ligne de fil ne peut donc pas partager sa transaction. L'ordre est
        // choisi — attribuer puis consigner — pour que le seul échec possible soit une
        // attribution sans sa ligne, jamais une ligne sans attribution. Un fil qui
        // annonce ce qui n'a pas eu lieu serait pire qu'un fil incomplet.
        journal.Consigner(
            eventId,
            contexte.MoiId,
            contexte.MonNom,
            ActivityKinds.ItemClaimed,
            new { libelle = contexte.Article!.Name });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var vue = await RelireAsync(eventId, itemId, contexte.MoiId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ArticleAttribue,
            vue,
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>Retire son attribution (EF-CRS-04). Seul l'attributaire peut le faire.</summary>
    public async Task<Result<ShoppingItemView>> LibererAsync(
        Guid eventId,
        Guid itemId,
        CancellationToken cancellationToken)
    {
        var contexte = await ContexteAsync(eventId, itemId, cancellationToken).ConfigureAwait(false);
        if (contexte.Erreur is not null)
        {
            return contexte.Erreur;
        }

        var article = contexte.Article!;

        if (article.AssignedMemberId is not null && article.AssignedMemberId != contexte.MoiId)
        {
            return NotClaimedByMe;
        }

        article.AssignedMemberId = null;
        article.AssignedAt = null;
        article.UpdatedAt = clock.UtcNow;

        journal.Consigner(
            eventId,
            contexte.MoiId,
            contexte.MonNom,
            ActivityKinds.ItemUnclaimed,
            new { libelle = article.Name });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var vue = await RelireAsync(eventId, itemId, contexte.MoiId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ArticleLibere,
            vue,
            cancellationToken).ConfigureAwait(false);
    }

    /// <summary>
    /// Déclare l'achat (EF-CRS-05, EF-CRS-06, EF-CRS-07).
    /// <para>
    /// La saisie d'un prix payé engendre la dépense correspondante. Le prix estimé
    /// n'entre jamais dans les calculs (RG-CRS-03) : c'est une aide à la préparation,
    /// pas un engagement.
    /// </para>
    /// </summary>
    public async Task<Result<ShoppingItemView>> AcheterAsync(
        Guid eventId,
        Guid itemId,
        PurchaseRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var contexte = await ContexteAsync(eventId, itemId, cancellationToken).ConfigureAwait(false);
        if (contexte.Erreur is not null)
        {
            return contexte.Erreur;
        }

        if (requete.ActualPrice is <= 0m)
        {
            return PriceOutOfRange;
        }

        if (requete.PurchasedQuantity is <= 0m)
        {
            return QuantityOutOfRange;
        }

        var article = contexte.Article!;

        // Déclarer l'achat d'autrui créerait une dépense à son nom, donc une créance
        // qu'il n'a jamais avancée. Une personne qui gère l'événement peut le faire à sa
        // place — la dépense reste alors au nom de celui qui s'en occupait, puisque
        // c'est lui qui a sorti l'argent.
        if (article.AssignedMemberId is { } attributaire
            && attributaire != contexte.MoiId
            && !contexte.JeGere)
        {
            return NotClaimedByMe;
        }

        // Acheter vaut s'attribuer : personne ne paie un article qu'il n'a pas pris.
        article.AssignedMemberId ??= contexte.MoiId;
        article.AssignedAt ??= clock.UtcNow;
        article.IsPurchased = true;
        article.PurchasedQuantity = requete.PurchasedQuantity ?? article.Quantity;
        article.ActualPrice = requete.ActualPrice;
        article.UpdatedAt = clock.UtcNow;

        // Le montant n'est porté que s'il a été déclaré : un zéro serait lu comme un
        // prix, alors qu'il n'y a pas eu de saisie.
        journal.Consigner(
            eventId,
            contexte.MoiId,
            contexte.MonNom,
            ActivityKinds.ItemPurchased,
            requete.ActualPrice is { } prixConsigne
                ? new { libelle = article.Name, montant = prixConsigne }
                : (object)new { libelle = article.Name });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        if (requete.ActualPrice is { } prix)
        {
            await depenses
                .UpsertAsync(
                    eventId,
                    itemId,
                    article.Name,
                    prix,
                    article.AssignedMemberId!.Value,
                    cancellationToken)
                .ConfigureAwait(false);
        }
        else
        {
            // Prix retiré : la dépense qui en découlait n'a plus de raison d'être.
            await depenses.RemoveForItemAsync(eventId, itemId, cancellationToken)
                .ConfigureAwait(false);
        }

        var vue = await RelireAsync(eventId, itemId, contexte.MoiId, cancellationToken)
            .ConfigureAwait(false);

        return await DiffuserAsync(
            eventId,
            MessagesTempsReel.ArticleAchete,
            vue,
            cancellationToken).ConfigureAwait(false);
    }

    // --------------------------------------------------------------- outils ----

    /// <summary>
    /// Article visé, appelant, et droit de gestion. <c>JeGere</c> distingue une
    /// personne qui arbitre l'événement d'un simple participant : elle seule agit sur
    /// ce qui appartient à autrui.
    /// </summary>
    private async Task<(ShoppingItem? Article, Guid MoiId, string MonNom, bool JeGere, DomainError? Erreur)>
        ContexteAsync(
            Guid eventId,
            Guid itemId,
            CancellationToken cancellationToken)
    {
        var moi = await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (moi is null)
        {
            return (null, Guid.Empty, string.Empty, false, EventNotFound);
        }

        var article = await db.ShoppingItems
            .FirstOrDefaultAsync(i => i.EventId == eventId && i.Id == itemId, cancellationToken)
            .ConfigureAwait(false);

        return article is null
            ? (null, moi.MemberId, moi.DisplayName, moi.CanManage, NotFound)
            : (article, moi.MemberId, moi.DisplayName, moi.CanManage, null);
    }

    private async Task<Result<ShoppingItemView>> RelireAsync(
        Guid eventId,
        Guid itemId,
        Guid moiId,
        CancellationToken cancellationToken)
    {
        var article = await db.ShoppingItems
            .AsNoTracking()
            .FirstOrDefaultAsync(i => i.EventId == eventId && i.Id == itemId, cancellationToken)
            .ConfigureAwait(false);

        return article is null
            ? NotFound
            : Result<ShoppingItemView>.Success(Vue(
                article,
                moiId,
                await NomsAsync(eventId, cancellationToken).ConfigureAwait(false)));
    }

    private async Task<Dictionary<Guid, EventMemberRef>> NomsAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var membres = await membership.ListActiveAsync(eventId, cancellationToken).ConfigureAwait(false);

        return membres.ToDictionary(m => m.MemberId);
    }

    /// <summary>
    /// Diffuse le résultat d'une mutation, et le renvoie tel quel.
    /// <para>
    /// Une aide plutôt qu'un appel répété six fois : l'oubli d'une diffusion ne se voit
    /// pas — l'endpoint répond correctement, seuls les autres écrans restent muets.
    /// Ne diffuse rien sur un échec : il n'y a alors aucun état résultant.
    /// </para>
    /// </summary>
    private async Task<Result<ShoppingItemView>> DiffuserAsync(
        Guid eventId,
        string message,
        Result<ShoppingItemView> resultat,
        CancellationToken cancellationToken)
    {
        if (resultat.IsSuccess)
        {
            await diffusion
                .PublierAsync(eventId, message, resultat.Value!, cancellationToken)
                .ConfigureAwait(false);
        }

        return resultat;
    }

    private static ShoppingItemView Vue(
        ShoppingItem article,
        Guid moiId,
        IReadOnlyDictionary<Guid, EventMemberRef> noms) =>
        new(
            article.Id,
            article.Name,
            article.Quantity,
            article.Unit,
            article.Category.ToString(),
            article.AssignedMemberId,
            article.AssignedMemberId is { } assigne
                ? noms.GetValueOrDefault(assigne)?.DisplayName
                : null,
            article.AssignedMemberId is { } avecPhoto
                ? noms.GetValueOrDefault(avecPhoto)?.AvatarUrl
                : null,
            article.AssignedMemberId == moiId,
            article.IsPurchased,
            article.PurchasedQuantity,
            article.RemainingQuantity,
            article.EstimatedPrice,
            article.ActualPrice,
            article.Note);

    private static DomainError? Valider(ShoppingItemRequest requete, out ShoppingCategory categorie)
    {
        categorie = ShoppingCategory.Other;

        if (string.IsNullOrWhiteSpace(requete.Name) || requete.Name.Trim().Length > 120)
        {
            return NameRequired;
        }

        if (requete.Quantity is <= 0m)
        {
            return QuantityOutOfRange;
        }

        if (requete.Category is null)
        {
            return null;
        }

        if (!Enum.TryParse(requete.Category, out categorie))
        {
            return UnknownCategory;
        }

        return null;
    }
}
