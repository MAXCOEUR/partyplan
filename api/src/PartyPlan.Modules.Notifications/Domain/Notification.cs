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

    /// <summary>
    /// Clé d'unicité. Forme : <c>{eventId}:{categorie}:{destinataire}:{occurrence}</c>,
    /// où l'occurrence vaut <c>j-3</c>, <c>j-1</c>, <c>debut</c>, <c>lendemain</c> pour
    /// un rappel temporel, et l'identifiant de l'action pour une notification née d'un
    /// geste.
    /// <para>
    /// Le doublon est refusé par la base et non par l'application : l'ordonnanceur
    /// balaie toutes les minutes, et vérifier puis écrire laisserait ouverte exactement
    /// la fenêtre qu'il exploiterait. C'est cette contrainte qui rend la planification
    /// rejouable sans conséquence.
    /// </para>
    /// </summary>
    public string DedupKey { get; set; } = string.Empty;
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
