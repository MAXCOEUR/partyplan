namespace PartyPlan.Modules.Notifications.Domain;

/// <summary>Notification destinée à une personne (§5.12).</summary>
public sealed class Notification
{
    public Guid Id { get; set; }

    /// <summary>Destinataire titulaire d'un compte. Nul pour un invité sans compte.</summary>
    public Guid? UserId { get; set; }

    /// <summary>Destinataire au sein d'un événement, y compris sans compte.</summary>
    public Guid? MemberId { get; set; }

    public Guid? EventId { get; set; }

    public string Category { get; set; } = string.Empty;

    public string Title { get; set; } = string.Empty;

    public string Body { get; set; } = string.Empty;

    /// <summary>Route applicative ouverte au clic, par exemple <c>/events/{id}/expenses</c>.</summary>
    public string? DeepLink { get; set; }

    /// <summary>Instant d'envoi souhaité. Décalé pour respecter la plage de silence (RG-NOT-01).</summary>
    public DateTimeOffset ScheduledFor { get; set; }

    public DateTimeOffset? SentAt { get; set; }

    public DateTimeOffset? ReadAt { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
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

    public static readonly string[] All =
    [
        InvitationAnswer,
        EventChanged,
        InvitationPending,
        ShoppingUnclaimed,
        EventStartingSoon,
        BalanceDue,
        Activity,
    ];
}

/// <summary>Préférence par destinataire et par catégorie (EF-NOT-07).</summary>
public sealed class NotificationPreference
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Category { get; set; } = string.Empty;

    public bool PushEnabled { get; set; } = true;

    public bool EmailEnabled { get; set; } = true;

    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>
/// Mise en sourdine d'un événement (EF-NOT-08). Distincte des préférences par catégorie :
/// on peut vouloir tout recevoir, sauf pour un événement donné.
/// </summary>
public sealed class EventMuteSetting
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid EventId { get; set; }

    public DateTimeOffset MutedAt { get; set; }
}

/// <summary>Appareil enregistré pour les notifications poussées.</summary>
public sealed class PushDevice
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Token { get; set; } = string.Empty;

    public string Platform { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset LastSeenAt { get; set; }

    public DateTimeOffset? DisabledAt { get; set; }
}
