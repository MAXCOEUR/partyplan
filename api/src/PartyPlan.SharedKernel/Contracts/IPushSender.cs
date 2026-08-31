namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Envoi d'une notification poussée. Implémenté par l'Infrastructure.
/// <para>
/// En l'absence de clé configurée, l'implémentation journalise en console et renvoie un
/// succès : une action métier ne doit jamais échouer parce qu'une notification n'a pas
/// pu partir (NF-DEV-04). Perdre l'avis vaut mieux que perdre la dépense qui l'a
/// déclenché.
/// </para>
/// </summary>
public interface IPushSender
{
    /// <summary>Vrai lorsqu'un fournisseur est réellement configuré.</summary>
    bool IsConfigured { get; }

    Task SendAsync(PushMessage message, CancellationToken cancellationToken);
}

/// <summary>Notification poussée destinée à un appareil.</summary>
/// <param name="DeviceToken">Jeton FCM de l'appareil destinataire.</param>
/// <param name="Title">Titre affiché.</param>
/// <param name="Body">Corps affiché.</param>
/// <param name="DeepLink">Destination ouverte au tap, ou <c>null</c> si aucune.</param>
/// <param name="GroupKey">
/// Clé d'empilement sur l'appareil (<c>RG-NOT-02</c>), sous la forme
/// <c>event:{eventId}</c>. L'émetteur ne peut pas la déduire lui-même : il ne lit pas la
/// table des notifications (règle 6, frontières de modules). Elle voyage donc depuis
/// <c>EnvoiNotifications</c>, qui tient la notification et son événement.
/// </param>
/// <param name="Category">
/// Constante de <see cref="NotificationCategories"/>. Voyage jusqu'au client parce que
/// lui seul sait ce qu'il affiche à l'instant où la notification arrive : sans elle, une
/// application ouverte ne peut pas distinguer le message qu'elle montre déjà de celui
/// qu'elle doit annoncer.
/// </param>
/// <param name="EventId">
/// Soirée concernée, ou <c>null</c> pour une notification qui n'en relève pas. Distincte
/// de <paramref name="GroupKey"/>, qui la porte préfixée pour l'empilement : le client a
/// besoin de l'identifiant nu pour le comparer à la soirée qu'il affiche.
/// </param>
public sealed record PushMessage(
    string DeviceToken,
    string Title,
    string Body,
    string? DeepLink = null,
    string? GroupKey = null,
    string? Category = null,
    string? EventId = null);
