namespace PartyPlan.SharedKernel.Contracts;

/// <summary>Notification à envoyer, telle qu'un module la décrit.</summary>
/// <param name="UserId">Destinataire titulaire d'un compte.</param>
/// <param name="EventId">Événement concerné. Sert la mise en sourdine (EF-NOT-08).</param>
/// <param name="Category">Une constante de <c>NotificationCategories</c>.</param>
/// <param name="Title">Titre affiché sur l'appareil.</param>
/// <param name="Body">Corps du message.</param>
/// <param name="DeepLink">Route applicative ouverte au tap. Nulle si aucune.</param>
/// <param name="ScheduledFor">
/// Instant souhaité. La plage de silence (RG-NOT-01) n'est <b>pas</b> appliquée ici : la
/// file porte l'intention, et c'est l'envoi qui la respecte.
/// </param>
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
