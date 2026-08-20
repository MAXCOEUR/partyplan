namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Aperçu d'un événement avant participation (RG-INV-04).
/// <para>
/// Volontairement pauvre : nom, date, lieu, nombre de participants. Ni liste nominative,
/// ni dépenses, ni discussion. Quiconque détient le lien voit ceci, et rien de plus,
/// jusqu'à ce qu'il rejoigne.
/// </para>
/// </summary>
public sealed record JoinPreview(
    string Name,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    string? Address,
    string? Description,
    int ParticipantCount,
    bool JoinEnabled,
    bool AlreadyMember);

/// <summary>Résultat d'une participation : la session d'invité, ou la confirmation d'adhésion.</summary>
public sealed record JoinResult(
    Guid EventId,
    Guid MemberId,
    string? GuestToken,
    DateTimeOffset? GuestTokenExpiresAt);

/// <summary>
/// Participation à un événement par lien ou par code court (EF-INV-04).
/// <para>
/// Chemin le plus critique du produit pour l'adoption : toute friction ajoutée ici se
/// paie en taux de réponse (§1.4). Deux écrans au maximum, aucun compte exigé.
/// </para>
/// </summary>
public sealed class JoinService(
    IEventsDbContext db,
    ICurrentUser currentUser,
    IEventScope scope,
    ITokenService tokens,
    IClock clock,
    IIdGenerator ids)
{
    public static readonly DomainError InvitationNotFound = DomainError.NotFound(
        "invitation.not_found",
        "Cette invitation n'existe pas, ou n'est plus valable.");

    public static readonly DomainError JoinClosed = DomainError.Rule(
        "invitation.closed",
        "L'organisateur a fermé les arrivées pour cet événement.");

    public static readonly DomainError NameRequired = DomainError.Validation(
        "invitation.name_required",
        "Indique ton prénom pour rejoindre.");

    /// <summary>Aperçu par jeton de lien.</summary>
    public Task<Result<JoinPreview>> ApercuParJetonAsync(
        string token,
        CancellationToken cancellationToken) =>
        ApercuAsync(e => e.InviteToken == token, cancellationToken);

    /// <summary>
    /// Aperçu par code court. La normalisation tolère les formes de saisie ; la
    /// limitation de débit est appliquée par l'endpoint (RG-INV-03).
    /// </summary>
    public Task<Result<JoinPreview>> ApercuParCodeAsync(
        string? code,
        CancellationToken cancellationToken)
    {
        if (!ShortCode.TryNormalize(code, out var normalise))
        {
            return Task.FromResult(Result<JoinPreview>.Failure(InvitationNotFound));
        }

        return ApercuAsync(e => e.ShortCode == normalise, cancellationToken);
    }

    /// <summary>
    /// Rejoint un événement. Un compte connecté est rattaché ; sinon un membre sans
    /// compte est créé, et un jeton d'invité restreint à cet événement est remis.
    /// </summary>
    public async Task<Result<JoinResult>> RejoindreAsync(
        string token,
        string displayName,
        EventMemberStatus statut,
        TimeOnly? arrivee,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(displayName) || displayName.Trim().Length > 120)
        {
            return NameRequired;
        }

        var evenement = await TrouverAsync(e => e.InviteToken == token, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return InvitationNotFound;
        }

        using var acces = scope.AllowTemporarily(evenement.Id);

        // Un membre déjà présent ne crée pas de doublon : le lien est souvent réouvert.
        var existant = await MembreExistantAsync(evenement.Id, cancellationToken)
            .ConfigureAwait(false);

        if (existant is not null)
        {
            existant.Status = statut;
            existant.ArrivalTime = arrivee ?? existant.ArrivalTime;

            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

            return Resultat(evenement.Id, existant);
        }

        if (!evenement.JoinEnabled)
        {
            return JoinClosed;
        }

        var membre = new EventMember
        {
            Id = ids.NewId(),
            EventId = evenement.Id,
            UserId = currentUser.UserId,
            DisplayName = displayName.Trim(),
            Status = statut,
            ArrivalTime = arrivee,
            JoinedAt = clock.UtcNow,
        };

        string? jetonInvite = null;
        DateTimeOffset? expiration = null;

        if (currentUser.UserId is null)
        {
            // Le jeton d'invité est la seule preuve d'identité de cette personne. Son
            // empreinte est conservée : c'est elle, et jamais le prénom, qui permettra le
            // rattachement à un compte créé plus tard (RG-AUTH-07).
            var acces_invite = tokens.CreateGuestToken(evenement.Id, membre.Id);
            jetonInvite = acces_invite.Value;
            expiration = acces_invite.ExpiresAt;
            membre.GuestSessionHash = Empreinte(acces_invite.Value);
        }

        db.EventMembers.Add(membre);

        db.ActivityEntries.Add(new ActivityEntry
        {
            Id = ids.NewId(),
            EventId = evenement.Id,
            MemberId = membre.Id,
            ActorName = membre.DisplayName,
            Kind = ActivityKinds.MemberJoined,
            CreatedAt = clock.UtcNow,
        });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return new JoinResult(evenement.Id, membre.Id, jetonInvite, expiration);
    }

    private static JoinResult Resultat(Guid eventId, EventMember membre) =>
        new(eventId, membre.Id, null, null);

    /// <summary>
    /// Empreinte du jeton d'invité, déléguée à <see cref="GuestMembershipLinking"/>.
    /// <para>
    /// Un seul calcul dans le module : deux implémentations qui divergeraient d'un
    /// octet feraient qu'aucune participation ne serait jamais rattachée à un compte,
    /// sans la moindre erreur visible.
    /// </para>
    /// </summary>
    private static string Empreinte(string valeur) =>
        GuestMembershipLinking.Empreinte(valeur);

    private async Task<Result<JoinPreview>> ApercuAsync(
        System.Linq.Expressions.Expression<Func<Event, bool>> critere,
        CancellationToken cancellationToken)
    {
        var evenement = await TrouverAsync(critere, cancellationToken).ConfigureAwait(false);

        if (evenement is null)
        {
            return InvitationNotFound;
        }

        using var acces = scope.AllowTemporarily(evenement.Id);

        var participants = await db.EventMembers
            .CountAsync(m => m.EventId == evenement.Id && m.RemovedAt == null, cancellationToken)
            .ConfigureAwait(false);

        var dejaMembre = await MembreExistantAsync(evenement.Id, cancellationToken)
            .ConfigureAwait(false) is not null;

        return new JoinPreview(
            evenement.Name,
            evenement.StartsAt,
            evenement.EndsAt,
            evenement.Address,
            evenement.Description,
            participants,
            evenement.JoinEnabled,
            dejaMembre);
    }

    /// <summary>
    /// Recherche l'événement en ignorant le cloisonnement : par construction, l'appelant
    /// n'en est pas encore membre. C'est le jeton ou le code qui autorise l'accès, et la
    /// vue renvoyée est restreinte à ce que RG-INV-04 permet.
    /// </summary>
    private Task<Event?> TrouverAsync(
        System.Linq.Expressions.Expression<Func<Event, bool>> critere,
        CancellationToken cancellationToken) =>
        db.Events
            .IgnoreQueryFilters()
            .Where(e => e.DeletedAt == null && e.ArchivedAt == null)
            .FirstOrDefaultAsync(critere, cancellationToken);

    private async Task<EventMember?> MembreExistantAsync(Guid eventId, CancellationToken cancellationToken)
    {
        if (currentUser.UserId is { } utilisateur)
        {
            return await db.EventMembers
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(
                    m => m.EventId == eventId && m.UserId == utilisateur && m.RemovedAt == null,
                    cancellationToken)
                .ConfigureAwait(false);
        }

        if (currentUser.GuestEventId == eventId)
        {
            return await db.EventMembers
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(
                    m => m.EventId == eventId && m.UserId == null && m.RemovedAt == null,
                    cancellationToken)
                .ConfigureAwait(false);
        }

        return null;
    }
}
