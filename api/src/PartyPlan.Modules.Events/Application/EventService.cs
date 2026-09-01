namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Création d'un événement (EF-EVT-01, EF-EVT-02).</summary>
public sealed record CreateEventRequest(
    string Name,
    string? Description,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    string? Address);

/// <summary>Modification (EF-EVT-03). Un champ absent reste inchangé.</summary>
public sealed record UpdateEventRequest(
    string? Name,
    string? Description,
    DateTimeOffset? StartsAt,
    DateTimeOffset? EndsAt,
    string? Address);

/// <summary>Événement tel qu'il apparaît dans la liste d'accueil (EF-EVT-05).</summary>
public sealed record EventListItem(
    Guid Id,
    string Name,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    string? Address,
    string? CoverImageUrl,
    int Invited,
    int Present,
    string MyRole,
    string MyStatus,
    bool IsPast);

/// <summary>Coordonnées de partage d'un événement (EF-INV-01 à EF-INV-03).</summary>
public sealed record EventInvitation(string Token, string ShortCode, string JoinUrl, bool JoinEnabled);

/// <summary>
/// Cycle de vie d'un événement.
/// <para>
/// Aucun contrôle d'appartenance n'apparaît dans les lectures : le filtre global du
/// DbContext l'applique déjà (RG-SEC-01). Les contrôles explicites portent uniquement sur
/// les <b>rôles</b> au sein d'un événement déjà visible.
/// </para>
/// </summary>
public sealed class EventService(
    IEventsDbContext db,
    ICurrentUser currentUser,
    IEventScope scope,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IJournalActivite journal,
    IFileNotifications notifications,
    QuotaEvenements quota,
    IFormuleCompte formule)
{
    /// <summary>Nombre de tentatives de tirage d'un code court avant abandon.</summary>
    private const int ShortCodeAttempts = 5;

    public static readonly DomainError NotFound = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NotAMember = DomainError.NotFound(
        "event.not_found",
        "Cet événement est introuvable.");

    public static readonly DomainError NameRequired = DomainError.Validation(
        "event.name_required",
        "Donne un nom à ton événement.");

    public static readonly DomainError EndBeforeStart = DomainError.Validation(
        "event.end_before_start",
        "La fin ne peut pas précéder le début.");

    public static readonly DomainError ShortCodeExhausted = DomainError.Conflict(
        "event.short_code_exhausted",
        "Impossible de générer un code d'invitation. Réessaie.");

    public static readonly DomainError SettlementsPending = DomainError.Rule(
        "event.settlements_pending",
        "Des remboursements restent en attente. Supprimer effacerait les comptes de tous "
        + "les participants.");

    // ------------------------------------------------------------- création ----

    public async Task<Result<EventSummary>> CreateAsync(
        CreateEventRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        if (currentUser.UserId is not { } utilisateur)
        {
            return DomainError.Forbidden("event.account_required", "Crée un compte pour organiser un événement.");
        }

        var validation = Valider(requete.Name, requete.StartsAt, requete.EndsAt);
        if (validation.IsFailure)
        {
            return validation.Error!;
        }

        // Le quota est vérifié avant le tirage du code court : inutile d'en consommer une
        // tentative pour une création qui sera refusée (RG-PRM-01, ADR 0008). Le comptage
        // est évité pour un abonné, dont la formule lève la borne.
        var abonne = await formule.EstAbonneAsync(utilisateur, cancellationToken)
            .ConfigureAwait(false);

        if (!abonne)
        {
            var possedes = await quota.CompterPossedesAsync(utilisateur, cancellationToken)
                .ConfigureAwait(false);

            if (!QuotaEvenements.CreationAutorisee(possedes, abonne))
            {
                return QuotaEvenements.QuotaAtteint;
            }
        }

        var code = await TirerCodeCourtAsync(cancellationToken).ConfigureAwait(false);
        if (code.IsFailure)
        {
            return code.Error!;
        }

        var evenement = new Event
        {
            Id = ids.NewId(),
            Name = requete.Name.Trim(),
            Description = requete.Description?.Trim(),
            StartsAt = requete.StartsAt,
            EndsAt = requete.EndsAt,
            Address = requete.Address?.Trim(),
            InviteToken = InviteToken.Generate(),
            ShortCode = code.Value,
            CreatedByUserId = utilisateur,
        };

        // Le créateur devient propriétaire et est déclaré présent : il organise, il vient.
        evenement.Members.Add(new EventMember
        {
            Id = ids.NewId(),
            EventId = evenement.Id,
            UserId = utilisateur,
            DisplayName = "Organisateur",
            Role = EventMemberRole.Owner,
            Status = EventMemberStatus.Going,
            JoinedAt = clock.UtcNow,
        });

        db.Events.Add(evenement);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Le périmètre de la requête courante est élargi : sans cela, la lecture qui suit
        // immédiatement la création ne verrait pas l'événement (RG-SEC-01).
        using var acces = scope.AllowTemporarily(evenement.Id);

        return await LireAsync(evenement.Id, cancellationToken).ConfigureAwait(false);
    }

    // -------------------------------------------------------------- lecture ----

    public async Task<Result<EventSummary>> LireAsync(Guid eventId, CancellationToken cancellationToken)
    {
        var evenement = await db.Events
            .Include(e => e.Members)
            .FirstOrDefaultAsync(e => e.Id == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return NotFound;
        }

        var decompte = AttendanceCount.From(evenement.Members);

        return new EventSummary(
            evenement.Id,
            evenement.Name,
            evenement.Description,
            evenement.StartsAt,
            evenement.EndsAt,
            evenement.Address,
            evenement.CoverImageUrl,
            decompte.Invited,
            decompte.Present,
            decompte.Maybe,
            evenement.JoinEnabled);
    }

    /// <summary>Événements de l'appelant, séparés en « à venir » et « passés » (EF-EVT-05).</summary>
    public async Task<IReadOnlyList<EventListItem>> ListerAsync(CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;
        var moi = currentUser.UserId;

        var evenements = await db.Events
            .Include(e => e.Members)
            .Where(e => e.ArchivedAt == null)
            .OrderBy(e => e.StartsAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return
        [
            .. evenements.Select(e =>
            {
                var decompte = AttendanceCount.From(e.Members);
                var moiDansEvenement = e.Members
                    .FirstOrDefault(m => moi != null && m.UserId == moi && m.RemovedAt == null);

                return new EventListItem(
                    e.Id,
                    e.Name,
                    e.StartsAt,
                    e.EndsAt,
                    e.Address,
                    e.CoverImageUrl,
                    decompte.Invited,
                    decompte.Present,
                    (moiDansEvenement?.Role ?? EventMemberRole.Member).ToString(),
                    (moiDansEvenement?.Status ?? EventMemberStatus.Unknown).ToString(),
                    e.IsPast(maintenant));
            }),
        ];
    }

    public async Task<Result<EventInvitation>> LireInvitationAsync(
        Guid eventId,
        string publicBaseUrl,
        CancellationToken cancellationToken)
    {
        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (acteur is null)
        {
            return NotAMember;
        }

        var evenement = await db.Events
            .FirstOrDefaultAsync(e => e.Id == eventId, cancellationToken)
            .ConfigureAwait(false);

        return evenement is null
            ? NotFound
            : new EventInvitation(
                evenement.InviteToken,
                evenement.ShortCode,
                $"{publicBaseUrl.TrimEnd('/')}/join/{evenement.InviteToken}",
                evenement.JoinEnabled);
    }

    // ---------------------------------------------------------- modification ----

    public async Task<Result<EventSummary>> ModifierAsync(
        Guid eventId,
        UpdateEventRequest requete,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(requete);

        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (acteur is null)
        {
            return NotAMember;
        }

        if (!acteur.CanManageEvent)
        {
            return DomainError.Forbidden(
                "event.not_allowed_to_manage",
                "Seuls le propriétaire et les administrateurs modifient l'événement.");
        }

        var evenement = await db.Events
            .Include(e => e.Members)
            .FirstOrDefaultAsync(e => e.Id == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return NotFound;
        }

        var nom = requete.Name?.Trim() ?? evenement.Name;
        var debut = requete.StartsAt ?? evenement.StartsAt;
        var fin = requete.EndsAt ?? evenement.EndsAt;

        var validation = Valider(nom, debut, fin);
        if (validation.IsFailure)
        {
            return validation.Error!;
        }

        // EF-EVT-03 : un changement de date ou de lieu doit être signalé aux membres qui
        // ont déjà répondu. La détection a lieu ici, avant écrasement des valeurs.
        // Les deux champs sont distingués : sans cela, l'application ne peut pas dire
        // si c'est la date ou le lieu qui a bougé, et les deux cas n'en font qu'un à
        // l'affichage.
        var dateChange = debut != evenement.StartsAt || fin != evenement.EndsAt;
        var lieuChange = requete.Address is not null
                         && requete.Address.Trim() != evenement.Address;
        var dateOuLieuChange = dateChange || lieuChange;

        evenement.Name = nom;
        evenement.StartsAt = debut;
        evenement.EndsAt = fin;

        if (requete.Description is not null)
        {
            evenement.Description = requete.Description.Trim();
        }

        if (requete.Address is not null)
        {
            evenement.Address = requete.Address.Trim();
        }

        if (dateOuLieuChange)
        {
            List<string> champs = [];
            if (dateChange)
            {
                champs.Add("date");
            }

            if (lieuChange)
            {
                champs.Add("lieu");
            }

            journal.Consigner(
                evenement.Id,
                acteur.Id,
                acteur.DisplayName,
                ActivityKinds.EventDateOrPlaceChanged,
                new { champs });

            await PrevenirDuChangementAsync(
                    evenement, acteur, champs, cancellationToken)
                .ConfigureAwait(false);
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        var resume = await LireAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (resume.IsSuccess)
        {
            // Un changement de date ou de lieu est ce qui compte le plus pour les
            // invités : le leur montrer sans qu'ils rechargent est le premier usage du
            // temps réel.
            await diffusion
                .PublierAsync(
                    eventId,
                    MessagesTempsReel.EvenementModifie,
                    resume.Value!,
                    cancellationToken)
                .ConfigureAwait(false);
        }

        return resume;
    }

    public async Task<Result> DefinirOuvertureAsync(
        Guid eventId,
        bool ouvert,
        CancellationToken cancellationToken)
    {
        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);

        if (acteur is null)
        {
            return NotAMember;
        }

        if (!acteur.CanManageEvent)
        {
            return DomainError.Forbidden(
                "event.not_allowed_to_manage",
                "Seuls le propriétaire et les administrateurs ferment les arrivées.");
        }

        var evenement = await db.Events
            .FirstOrDefaultAsync(e => e.Id == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return NotFound;
        }

        evenement.JoinEnabled = ouvert;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>Régénère le lien d'invitation, invalidant le précédent (EF-INV-05).</summary>
    public async Task<Result<EventInvitation>> RegenererLienAsync(
        Guid eventId,
        string publicBaseUrl,
        CancellationToken cancellationToken)
    {
        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (acteur is null)
        {
            return NotAMember;
        }

        if (!acteur.CanManageEvent)
        {
            return DomainError.Forbidden(
                "event.not_allowed_to_manage",
                "Seuls le propriétaire et les administrateurs régénèrent le lien.");
        }

        var evenement = await db.Events
            .FirstOrDefaultAsync(e => e.Id == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return NotFound;
        }

        var code = await TirerCodeCourtAsync(cancellationToken).ConfigureAwait(false);
        if (code.IsFailure)
        {
            return code.Error!;
        }

        // Le code court est renouvelé avec le jeton : ne changer que le lien laisserait
        // une porte ouverte à quiconque connaît le code.
        evenement.InviteToken = InviteToken.Generate();
        evenement.ShortCode = code.Value;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return new EventInvitation(
            evenement.InviteToken,
            evenement.ShortCode,
            $"{publicBaseUrl.TrimEnd('/')}/join/{evenement.InviteToken}",
            evenement.JoinEnabled);
    }

    // ------------------------------------------------------------ suppression ----

    public async Task<Result> SupprimerAsync(
        Guid eventId,
        bool forcer,
        CancellationToken cancellationToken)
    {
        var acteur = await MembreCourantAsync(eventId, cancellationToken).ConfigureAwait(false);
        if (acteur is null)
        {
            return NotAMember;
        }

        if (!acteur.CanDeleteEvent)
        {
            return DomainError.Forbidden(
                "event.only_owner_deletes",
                "Seul le propriétaire peut supprimer l'événement.");
        }

        var evenement = await db.Events
            .FirstOrDefaultAsync(e => e.Id == eventId, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return NotFound;
        }

        // RG-EVT-02 : la vérification des règlements en attente relève du module
        // Settlements. Elle sera branchée par contrat au lot 1.8 ; d'ici là, la
        // confirmation renforcée est la seule barrière, et le drapeau la matérialise.
        if (!forcer)
        {
            return SettlementsPending;
        }

        evenement.DeletedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    // ---------------------------------------------------------------- outils ----

    /// <summary>
    /// Prévient les membres d'un changement de date ou de lieu (EF-NOT-02).
    /// <para>
    /// Tous sauf l'auteur : il vient de le faire. La clé de déduplication porte
    /// l'horodatage du changement, si bien qu'un second déplacement de date prévient de
    /// nouveau — c'est précisément ce qui doit remonter.
    /// </para>
    /// </summary>
    private async Task PrevenirDuChangementAsync(
        Event evenement,
        EventMember acteur,
        List<string> champs,
        CancellationToken cancellationToken)
    {
        var destinataires = await db.EventMembers
            .Where(m => m.EventId == evenement.Id
                        && m.UserId != null
                        && m.Id != acteur.Id
                        && m.RemovedAt == null)
            .Select(m => m.UserId!.Value)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var quoi = champs.Count == 2
            ? "la date et le lieu"
            : champs[0] == "date" ? "la date" : "le lieu";

        var instant = clock.UtcNow;

        foreach (var destinataire in destinataires)
        {
            notifications.Enfiler(new NotificationAEnvoyer(
                destinataire,
                evenement.Id,
                NotificationCategories.EventChanged,
                evenement.Name,
                $"{acteur.DisplayName} a modifié {quoi}.",
                DestinationsNotification.Soiree(evenement.Id),
                instant,
                $"{evenement.Id}:{NotificationCategories.EventChanged}:"
                + $"{destinataire}:{instant.ToUnixTimeSeconds()}"));
        }
    }

    private static Result Valider(string? nom, DateTimeOffset debut, DateTimeOffset? fin)
    {
        if (string.IsNullOrWhiteSpace(nom) || nom.Trim().Length > 120)
        {
            return NameRequired;
        }

        return fin is not null && fin <= debut ? EndBeforeStart : Result.Success();
    }

    private async Task<EventMember?> MembreCourantAsync(Guid eventId, CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } moi)
        {
            return null;
        }

        return await db.EventMembers
            .FirstOrDefaultAsync(
                m => m.EventId == eventId && m.UserId == moi && m.RemovedAt == null,
                cancellationToken)
            .ConfigureAwait(false);
    }

    /// <summary>
    /// Tire un code court non déjà pris. L'unicité n'est exigée que parmi les événements
    /// vivants (RG-INV-02), ce qui laisse le stock se recycler.
    /// </summary>
    private async Task<Result<string>> TirerCodeCourtAsync(CancellationToken cancellationToken)
    {
        for (var tentative = 0; tentative < ShortCodeAttempts; tentative++)
        {
            var candidat = ShortCode.Generate();

            var pris = await db.Events
                .IgnoreQueryFilters()
                .AnyAsync(
                    e => e.ShortCode == candidat && e.ArchivedAt == null && e.DeletedAt == null,
                    cancellationToken)
                .ConfigureAwait(false);

            if (!pris)
            {
                return candidat;
            }
        }

        return ShortCodeExhausted;
    }
}
