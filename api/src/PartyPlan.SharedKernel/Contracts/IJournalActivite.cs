namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Inscription d'une ligne au fil d'activité d'un événement (EF-FIL-01).
/// <para>
/// Contrat du noyau partagé et non du module Events : quatre modules journalisent, et
/// aucun ne doit accéder à <c>activity_entries</c>. Même motif que
/// <see cref="IDiffusionEvenement"/> et <see cref="IAuditLog"/>.
/// </para>
/// <para>
/// <b>Garantie opposée à celle de la diffusion.</b> <see cref="IDiffusionEvenement"/>
/// part après validation et absorbe ses propres pannes : le temps réel est une
/// optimisation, et une diffusion perdue se rattrape à la relecture suivante. Le fil,
/// lui, est la trace de référence en cas de litige sur les montants (RG-FIL-02) : il
/// doit vivre ou mourir avec l'action qui l'a produit. Les deux contrats se ressemblent
/// et ne promettent pas la même chose.
/// </para>
/// </summary>
public interface IJournalActivite
{
    /// <summary>
    /// Inscrit l'entrée au suivi de modifications, <b>sans sauvegarder</b>. C'est le
    /// <c>SaveChangesAsync</c> de l'appelant qui la valide, dans la même transaction que
    /// l'action métier.
    /// <para>
    /// Synchrone et sans <c>Task</c> à dessein : une signature asynchrone laisserait
    /// croire qu'un aller-retour en base a lieu ici, et inviterait à sauvegarder.
    /// </para>
    /// </summary>
    /// <param name="eventId">Événement auquel la ligne appartient.</param>
    /// <param name="memberId">Auteur de l'action. Nul pour une action système.</param>
    /// <param name="actorName">
    /// Nom de l'auteur à cet instant. Figé volontairement : un changement de nom
    /// ultérieur ne doit pas réécrire l'histoire (RG-USR-04).
    /// </param>
    /// <param name="kind">Une constante de <c>ActivityKinds</c>.</param>
    /// <param name="donnees">
    /// Contexte sérialisé en JSON — libellé, montant, ancienne et nouvelle valeur.
    /// <b>Jamais une phrase</b> : la ligne est inaltérable, une formulation stockée le
    /// serait aussi, et le fil ne serait jamais traduisible (NF-I18N-01).
    /// </param>
    void Consigner(
        Guid eventId,
        Guid? memberId,
        string actorName,
        string kind,
        object? donnees = null);
}

/// <summary>
/// Catégories du fil d'activité. Les treize catégories exigées par RG-FIL-01 sont
/// couvertes ; ne jamais renommer une valeur déjà écrite en base.
/// </summary>
public static class ActivityKinds
{
    public const string MemberJoined = "member.joined";
    public const string MemberStatusChanged = "member.status_changed";
    public const string ItemCreated = "item.created";
    public const string ItemDeleted = "item.deleted";
    public const string ItemClaimed = "item.claimed";
    public const string ItemUnclaimed = "item.unclaimed";
    public const string ItemPurchased = "item.purchased";
    public const string ExpenseCreated = "expense.created";
    public const string ExpenseUpdated = "expense.updated";
    public const string ExpenseDeleted = "expense.deleted";
    public const string SettlementMarked = "settlement.marked";
    public const string SettlementCancelled = "settlement.cancelled";
    public const string EventDateOrPlaceChanged = "event.date_or_place_changed";

    /// <summary>
    /// Toutes les catégories. Sert aux tests de couverture, et à l'application qui doit
    /// savoir composer une phrase pour chacune.
    /// </summary>
    public static readonly IReadOnlyList<string> All =
    [
        MemberJoined,
        MemberStatusChanged,
        ItemCreated,
        ItemDeleted,
        ItemClaimed,
        ItemUnclaimed,
        ItemPurchased,
        ExpenseCreated,
        ExpenseUpdated,
        ExpenseDeleted,
        SettlementMarked,
        SettlementCancelled,
        EventDateOrPlaceChanged,
    ];
}
