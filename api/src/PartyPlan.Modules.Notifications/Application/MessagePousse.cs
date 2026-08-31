namespace PartyPlan.Modules.Notifications.Application;

using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Traduction d'une notification enregistrée en message poussé.
/// <para>
/// Extraite de la passe d'envoi pour être vérifiable seule : ce qui part vers l'appareil
/// détermine ce que l'application saura en faire, et une correspondance muette est celle
/// qu'on relit sans jamais l'éprouver.
/// </para>
/// </summary>
public static class MessagePousse
{
    /// <summary>Message destiné à un appareil, pour une notification donnée.</summary>
    public static PushMessage Depuis(Notification notification, string jetonAppareil)
    {
        ArgumentNullException.ThrowIfNull(notification);

        return new PushMessage(
            jetonAppareil,
            notification.Title,
            notification.Body,
            notification.DeepLink,
            // Préfixée pour l'empilement sur l'appareil (RG-NOT-02) ; l'identifiant nu
            // part à part, le client en ayant besoin tel quel.
            notification.EventId is { } evenement ? $"event:{evenement}" : null,
            notification.Category,
            notification.EventId?.ToString());
    }
}
