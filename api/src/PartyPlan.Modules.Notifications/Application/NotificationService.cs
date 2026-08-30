namespace PartyPlan.Modules.Notifications.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Une notification reçue, telle que l'application l'affiche.</summary>
public sealed record NotificationView(
    Guid Id,
    Guid? EventId,
    string Category,
    string Title,
    string Body,
    string? DeepLink,
    DateTimeOffset SentAt,
    bool Lue);

/// <summary>Une page de notifications, de la plus récente à la plus ancienne.</summary>
public sealed record NotificationPage(
    IReadOnlyList<NotificationView> Items,
    bool HasMore,
    int UnreadCount);

/// <summary>Préférence d'une catégorie (EF-NOT-07).</summary>
public sealed record PreferenceView(string Category, bool PushEnabled, bool EmailEnabled);

/// <summary>
/// Réglage résolu d'une catégorie pour une soirée donnée.
/// <para>
/// <c>Enabled</c> porte la valeur déjà résolue par <see cref="ResolutionPreference"/> —
/// écart de soirée, puis préférence globale, puis valeur d'usine — et non le seul écart :
/// l'écran ne doit pas rejouer cette résolution de son côté, sous peine de diverger un
/// jour de la règle serveur. <c>EstUnEcart</c> distingue une ligne posée pour cette
/// soirée d'une valeur simplement héritée.
/// </para>
/// <para>
/// La sourdine n'entre pas dans <c>Enabled</c> : voir
/// <see cref="NotificationService.PreferencesDeSoireeAsync"/>.
/// </para>
/// </summary>
public sealed record PreferenceDeSoireeView(string Category, bool Enabled, bool EstUnEcart);

/// <summary>
/// Notifications reçues et préférences (§5.12).
/// <para>
/// Chacun ne lit que les siennes. Aucun rôle plateforme n'y donne accès : un
/// administrateur qui lirait les notifications d'un compte connaîtrait le contenu de ses
/// soirées par la bande (RG-ADM-01).
/// </para>
/// </summary>
public sealed class NotificationService(
    INotificationsDbContext db,
    ICurrentUser appelant,
    IClock clock,
    IIdGenerator ids,
    IEventMembership membership)
{
    public const int LimiteParDefaut = 30;

    public const int LimiteMaximale = 100;

    public static readonly DomainError NonAuthentifie = DomainError.Unauthenticated(
        "auth.required",
        "Cette action demande une session.");

    public static readonly DomainError LimiteInvalide = DomainError.Validation(
        "notifications.limit_invalid",
        $"La limite doit être comprise entre 1 et {LimiteMaximale}.");

    public static readonly DomainError CategorieInconnue = DomainError.Validation(
        "notifications.unknown_category",
        "Cette catégorie de notification n'existe pas.");

    public static readonly DomainError Introuvable = DomainError.NotFound(
        "notifications.not_found",
        "Cette notification est introuvable.");

    // 404 et non 403 sur une soirée dont on n'est pas membre : confirmer son existence
    // renseignerait sur ce qui s'y passe (RG-SEC-01, cloisonnement).
    public static readonly DomainError EvenementIntrouvable = DomainError.NotFound(
        "notifications.event_not_found",
        "Cet événement est introuvable.");

    public async Task<Result<NotificationPage>> ListerAsync(
        Guid? avant,
        int limite,
        CancellationToken cancellationToken)
    {
        if (limite is < 1 or > LimiteMaximale)
        {
            return LimiteInvalide;
        }

        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        // Seules les notifications parties : une ligne encore en file n'a pas été
        // reçue, et l'afficher annoncerait un rappel avant qu'il ne soit dû.
        var requete = db.Notifications
            .Where(n => n.UserId == moi && n.SentAt != null);

        if (avant is { } curseur)
        {
            var repere = await db.Notifications
                .Where(n => n.Id == curseur && n.UserId == moi)
                .Select(n => new { n.SentAt, n.Id })
                .FirstOrDefaultAsync(cancellationToken)
                .ConfigureAwait(false);

            if (repere is not null)
            {
                requete = requete.Where(n =>
                    n.SentAt < repere.SentAt
                    || (n.SentAt == repere.SentAt && n.Id.CompareTo(repere.Id) < 0));
            }
        }

        var lignes = await requete
            .OrderByDescending(n => n.SentAt)
            .ThenByDescending(n => n.Id)
            .Take(limite + 1)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var encore = lignes.Count > limite;
        if (encore)
        {
            lignes.RemoveAt(lignes.Count - 1);
        }

        var nonLues = await db.Notifications
            .CountAsync(
                n => n.UserId == moi && n.SentAt != null && n.ReadAt == null,
                cancellationToken)
            .ConfigureAwait(false);

        return new NotificationPage(
            lignes.ConvertAll(n => new NotificationView(
                n.Id,
                n.EventId,
                n.Category,
                n.Title,
                n.Body,
                n.DeepLink,
                n.SentAt!.Value,
                n.ReadAt is not null)),
            encore,
            nonLues);
    }

    public async Task<Result> MarquerLueAsync(Guid id, CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        var notification = await db.Notifications
            .FirstOrDefaultAsync(n => n.Id == id && n.UserId == moi, cancellationToken)
            .ConfigureAwait(false);

        // 404 et non 403 sur la notification d'autrui : confirmer son existence
        // renseignerait sur ce qui se passe dans une soirée qui ne nous regarde pas.
        if (notification is null)
        {
            return Introuvable;
        }

        notification.ReadAt ??= clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<Result> ToutMarquerLuAsync(CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        var instant = clock.UtcNow;

        await db.Notifications
            .Where(n => n.UserId == moi && n.SentAt != null && n.ReadAt == null)
            .ExecuteUpdateAsync(
                mise => mise.SetProperty(n => n.ReadAt, instant),
                cancellationToken)
            .ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<PreferenceView>>> PreferencesAsync(
        CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        var enregistrees = await db.NotificationPreferences
            .Where(p => p.UserId == moi)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        // Les sept catégories sont toujours rendues, même sans ligne en base : une
        // préférence absente vaut « activée », et l'écran doit pouvoir afficher
        // l'ensemble sans savoir lesquelles ont déjà été touchées.
        return NotificationCategories.All
            .Select(categorie =>
            {
                var ligne = enregistrees.Find(p => p.Category == categorie);
                return new PreferenceView(
                    categorie,
                    ligne?.PushEnabled ?? true,
                    ligne?.EmailEnabled ?? true);
            })
            .ToList();
    }

    public async Task<Result> DefinirPreferenceAsync(
        string categorie,
        bool pousseeActivee,
        bool courrielActive,
        CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        if (!NotificationCategories.All.Contains(categorie))
        {
            return CategorieInconnue;
        }

        var ligne = await db.NotificationPreferences
            .FirstOrDefaultAsync(
                p => p.UserId == moi && p.Category == categorie,
                cancellationToken)
            .ConfigureAwait(false);

        if (ligne is null)
        {
            db.NotificationPreferences.Add(new NotificationPreference
            {
                Id = ids.NewId(),
                UserId = moi,
                Category = categorie,
                PushEnabled = pousseeActivee,
                EmailEnabled = courrielActive,
                UpdatedAt = clock.UtcNow,
            });
        }
        else
        {
            ligne.PushEnabled = pousseeActivee;
            ligne.EmailEnabled = courrielActive;
            ligne.UpdatedAt = clock.UtcNow;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Réglages résolus, catégorie par catégorie, pour cette soirée.
    /// <para>
    /// <b>Décision</b> : la sourdine de la soirée reste hors de cette résolution — elle
    /// n'est pas repliée dans les onze catégories, qui restent « activées » même sur une
    /// soirée en sourdine. La replier ferait afficher onze « non » sur une soirée
    /// muette, et la remise en son ressemblerait à un changement de onze préférences
    /// alors que la personne n'en a touché aucune. La sourdine est un interrupteur
    /// général, déjà exposé séparément par <c>GET /events/{eventId}/mute</c> : c'est à
    /// l'écran d'afficher cet état à côté des catégories, pas à cet endpoint de le
    /// simuler dans chacune d'elles.
    /// </para>
    /// </summary>
    public async Task<Result<IReadOnlyList<PreferenceDeSoireeView>>> PreferencesDeSoireeAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        if (await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false) is null)
        {
            return EvenementIntrouvable;
        }

        var ecarts = await db.EventNotificationPreferences
            .Where(p => p.UserId == moi && p.EventId == eventId)
            .ToDictionaryAsync(p => p.Category, p => p.Enabled, cancellationToken)
            .ConfigureAwait(false);

        var globales = await db.NotificationPreferences
            .Where(p => p.UserId == moi)
            .ToDictionaryAsync(p => p.Category, p => p.PushEnabled, cancellationToken)
            .ConfigureAwait(false);

        return NotificationCategories.All
            .Select(categorie =>
            {
                var ecart = ecarts.TryGetValue(categorie, out var e) ? (bool?)e : null;
                var globale = globales.TryGetValue(categorie, out var g) ? (bool?)g : null;

                return new PreferenceDeSoireeView(
                    categorie,
                    ResolutionPreference.EstActivee(ecart, globale),
                    EstUnEcart: ecart is not null);
            })
            .ToList();
    }

    public async Task<Result> DefinirPreferenceDeSoireeAsync(
        Guid eventId,
        string categorie,
        bool? actif,
        CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        // Appartenance avant validation de la catégorie, comme à la lecture : sans
        // conséquence de sécurité ici, mais les deux méthodes de ce fichier vérifient
        // le périmètre événement dans le même ordre.
        if (await membership.FindCurrentAsync(eventId, cancellationToken).ConfigureAwait(false) is null)
        {
            return EvenementIntrouvable;
        }

        if (!NotificationCategories.All.Contains(categorie))
        {
            return CategorieInconnue;
        }

        var ligne = await db.EventNotificationPreferences
            .FirstOrDefaultAsync(
                p => p.UserId == moi && p.EventId == eventId && p.Category == categorie,
                cancellationToken)
            .ConfigureAwait(false);

        if (actif is not { } valeur)
        {
            // Valeur nulle : retire l'écart, la soirée redevient réglée comme d'habitude.
            // Ce n'est pas une route de suppression distincte : l'écran a trois états à
            // écrire pour la discussion, dont l'un est « comme d'habitude ».
            if (ligne is not null)
            {
                db.EventNotificationPreferences.Remove(ligne);
            }
        }
        else if (ligne is null)
        {
            db.EventNotificationPreferences.Add(new EventNotificationPreference
            {
                Id = ids.NewId(),
                UserId = moi,
                EventId = eventId,
                Category = categorie,
                Enabled = valeur,
                UpdatedAt = clock.UtcNow,
            });
        }
        else
        {
            ligne.Enabled = valeur;
            ligne.UpdatedAt = clock.UtcNow;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<Result<bool>> SourdineAsync(Guid eventId, CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        return await db.EventMuteSettings
            .AnyAsync(m => m.UserId == moi && m.EventId == eventId, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<Result> DefinirSourdineAsync(
        Guid eventId,
        bool enSourdine,
        CancellationToken cancellationToken)
    {
        if (appelant.UserId is not { } moi)
        {
            return NonAuthentifie;
        }

        var ligne = await db.EventMuteSettings
            .FirstOrDefaultAsync(
                m => m.UserId == moi && m.EventId == eventId,
                cancellationToken)
            .ConfigureAwait(false);

        // Aucun contrôle d'appartenance : mettre en sourdine un événement dont on n'est
        // pas membre ne révèle rien et ne produit rien. Un contrôle exigerait de lire
        // event_members, table d'un autre module (règle 6).
        if (enSourdine && ligne is null)
        {
            db.EventMuteSettings.Add(new EventMuteSetting
            {
                Id = ids.NewId(),
                UserId = moi,
                EventId = eventId,
                MutedAt = clock.UtcNow,
            });
        }
        else if (!enSourdine && ligne is not null)
        {
            db.EventMuteSettings.Remove(ligne);
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }
}
