namespace PartyPlan.SharedKernel.Contracts;

/// <summary>Notification à envoyer, telle qu'un module la décrit.</summary>
/// <param name="UserId">Destinataire titulaire d'un compte.</param>
/// <param name="EventId">Événement concerné. Sert la mise en sourdine (EF-NOT-08).</param>
/// <param name="Category">Une constante de <c>NotificationCategories</c>.</param>
/// <param name="Title">Titre affiché sur l'appareil.</param>
/// <param name="Body">Corps du message.</param>
/// <param name="DeepLink">Route applicative ouverte au tap. Nulle si aucune.</param>
/// <param name="ScheduledFor">Instant d'envoi souhaité.</param>
/// <param name="DedupKey">
/// Clé d'unicité. Deux notifications de même clé ne coexistent jamais.
/// </param>
public sealed record NotificationAEnvoyer(
    Guid? UserId,
    Guid EventId,
    string Category,
    string Title,
    string Body,
    string? DeepLink,
    DateTimeOffset ScheduledFor,
    string DedupKey);

/// <summary>
/// Mise en file d'une notification. Contrat public du module Notifications, seul
/// propriétaire de la table <c>notifications</c>.
/// <para>
/// <b>Inscrit sans sauvegarder</b>, comme <see cref="IJournalActivite"/> : la ligne est
/// validée par le <c>SaveChangesAsync</c> de l'appelant, donc dans la transaction de
/// l'action. Une réponse à une invitation qui échoue ne doit pas laisser partir un avis
/// annonçant une réponse qui n'a pas eu lieu.
/// </para>
/// <para>
/// Une clé déjà enfilée est ignorée en silence. C'est le cas <b>normal</b> d'un balayage
/// rejoué, pas une erreur : l'ordonnanceur tourne toutes les minutes et recalcule les
/// mêmes rappels.
/// </para>
/// </summary>
public interface IFileNotifications
{
    void Enfiler(NotificationAEnvoyer notification);
}

/// <summary>
/// Catégories de notification. Chacune est désactivable individuellement (EF-NOT-07),
/// ce qui suppose une valeur stable en base.
/// </summary>
public static class NotificationCategories
{
    public const string InvitationAnswer = "invitation.answer";
    public const string EventChanged = "event.changed";
    public const string InvitationPending = "invitation.pending";
    public const string ShoppingUnclaimed = "shopping.unclaimed";
    public const string EventStartingSoon = "event.starting_soon";
    public const string BalanceDue = "balance.due";
    public const string Activity = "activity";

    /// <summary>Message posté dans la discussion, sans citation.</summary>
    public const string DiscussionMessage = "discussion.message";

    /// <summary>Message citant nommément le destinataire.</summary>
    public const string DiscussionMention = "discussion.mention";

    public const string PollNew = "poll.new";
    public const string ExpenseNew = "expense.new";

    public static readonly string[] All =
    [
        InvitationAnswer,
        EventChanged,
        InvitationPending,
        ShoppingUnclaimed,
        EventStartingSoon,
        BalanceDue,
        Activity,
        DiscussionMessage,
        DiscussionMention,
        PollNew,
        ExpenseNew,
    ];
}
