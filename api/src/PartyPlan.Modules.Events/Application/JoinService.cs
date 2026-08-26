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

/// <summary>Confirmation d'une participation.</summary>
public sealed record JoinResult(Guid EventId, Guid MemberId);

/// <summary>
/// Participation à un événement par lien ou par code court (EF-INV-04).
/// </summary>
public sealed class JoinService(
    IEventsDbContext db,
    ICurrentUser currentUser,
    IEventScope scope,
    IUserIdentityLookup users,
    IClock clock,
    IIdGenerator ids,
    IDiffusionEvenement diffusion,
    IJournalActivite journal)
{
    public static readonly DomainError InvitationNotFound = DomainError.NotFound(
        "invitation.not_found",
        "Cette invitation n'existe pas, ou n'est plus valable.");

    public static readonly DomainError JoinClosed = DomainError.Rule(
        "invitation.closed",
        "L'organisateur a fermé les arrivées pour cet événement.");

    public static readonly DomainError AccountRequired = new(
        "invitation.account_required",
        "Connecte-toi pour rejoindre cet événement.",
        ErrorKind.Unauthenticated);

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

    /// <summary>Rejoint un événement avec le compte de l'appelant.</summary>
    public Task<Result<JoinResult>> RejoindreAsync(
        string token,
        CancellationToken cancellationToken) =>
        RejoindreAsync(e => e.InviteToken == token, cancellationToken);

    /// <summary>
    /// Rejoint un événement à partir d'un code court (EF-INV-03).
    /// <para>
    /// Endpoint distinct plutôt que jeton révélé par l'aperçu : l'aperçu ne doit
    /// contenir aucun jeton (RG-INV-04), et le lui faire porter transformerait le code
    /// court — devinable en six caractères — en oracle à jetons d'invitation. La même
    /// limitation de débit que la résolution s'applique donc ici (RG-INV-03).
    /// </para>
    /// </summary>
    public Task<Result<JoinResult>> RejoindreParCodeAsync(
        string? code,
        CancellationToken cancellationToken)
    {
        if (!ShortCode.TryNormalize(code, out var normalise))
        {
            return Task.FromResult(Result<JoinResult>.Failure(InvitationNotFound));
        }

        return RejoindreAsync(e => e.ShortCode == normalise, cancellationToken);
    }

    private async Task<Result<JoinResult>> RejoindreAsync(
        System.Linq.Expressions.Expression<Func<Event, bool>> critere,
        CancellationToken cancellationToken)
    {
        if (currentUser.UserId is not { } userId)
        {
            return AccountRequired;
        }

        var identity = await users.FindAsync(userId, cancellationToken).ConfigureAwait(false);
        if (identity is null)
        {
            return AccountRequired;
        }

        var evenement = await TrouverAsync(critere, cancellationToken)
            .ConfigureAwait(false);

        if (evenement is null)
        {
            return InvitationNotFound;
        }

        using var acces = scope.AllowTemporarily(evenement.Id);

        // Un membre déjà présent ne crée pas de doublon : le lien est souvent réouvert.
        var existant = await MembreUtilisateurAsync(evenement.Id, userId, cancellationToken)
            .ConfigureAwait(false);

        if (existant is not null)
        {
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
            UserId = userId,
            DisplayName = identity.DisplayName,
            Status = EventMemberStatus.Unknown,
            JoinedAt = clock.UtcNow,
        };

        db.EventMembers.Add(membre);

        journal.Consigner(
            evenement.Id,
            membre.Id,
            membre.DisplayName,
            ActivityKinds.MemberJoined);

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await journal.PublierEnAttenteAsync(cancellationToken).ConfigureAwait(false);

        // L'état du nouveau membre, pas seulement son identifiant (RG-RT-02) : les
        // autres écrans doivent pouvoir l'afficher sans relire la liste entière. La
        // vue est construite ici plutôt que réutilisée d'un endpoint : ce service ne
        // renvoie qu'un identifiant, il n'a pas de MemberView sous la main.
        await diffusion
            .PublierAsync(
                evenement.Id,
                MessagesTempsReel.MembreArrive,
                new
                {
                    id = membre.Id,
                    displayName = membre.DisplayName,
                    status = membre.Status.ToString(),
                    role = membre.Role.ToString(),
                },
                cancellationToken)
            .ConfigureAwait(false);

        return new JoinResult(evenement.Id, membre.Id);
    }

    private static JoinResult Resultat(Guid eventId, EventMember membre) =>
        new(eventId, membre.Id);

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

        var dejaMembre = currentUser.UserId is { } userId
            && await MembreUtilisateurAsync(evenement.Id, userId, cancellationToken)
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

    private Task<EventMember?> MembreUtilisateurAsync(
        Guid eventId,
        Guid userId,
        CancellationToken cancellationToken) =>
        db.EventMembers
            .IgnoreQueryFilters()
            .FirstOrDefaultAsync(
                m => m.EventId == eventId && m.UserId == userId && m.RemovedAt == null,
                cancellationToken);
}
