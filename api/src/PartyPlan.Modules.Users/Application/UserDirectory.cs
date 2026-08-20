namespace PartyPlan.Modules.Users.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Implémentation du contrat public du module Users, consommé par l'administration.
/// <para>
/// La fiche renvoyée ne contient que des données techniques de compte : ni empreinte de
/// mot de passe, ni secret de double authentification, ni contenu d'événement
/// (RG-ADM-01, RG-RGPD-04). Le nombre d'événements est un simple décompte — savoir
/// qu'une personne participe à quatre événements ne révèle rien de leur contenu.
/// </para>
/// </summary>
public sealed class UserDirectory(
    IUsersDbContext db,
    AccountDeletionService deletion,
    AccountService accounts,
    IEventStatistics events,
    IClock clock) : IUserDirectory
{
    public const int MaxPageSize = 100;

    public async Task<UserPage> SearchAsync(UserQuery query, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(query);

        var page = Math.Max(1, query.Page);
        var taille = Math.Clamp(query.PageSize, 1, MaxPageSize);

        var source = db.Users.AsQueryable();

        if (!query.IncludeDeleted)
        {
            source = source.Where(u => u.DeletedAt == null);
        }

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            // `ILike` serait plus direct, mais appartient au fournisseur PostgreSQL :
            // l'utiliser ici ferait entrer Npgsql dans un module de domaine. La forme
            // ci-dessous se traduit en `lower(...) LIKE ...` chez tout fournisseur.
            //
            // Aucun index ne couvre `lower(display_name)` : c'est assumé, cette
            // recherche est réservée au back-office et porte sur des volumes que
            // NF-SCAL-01 borne à 50 000 comptes.
            var motif = $"%{query.Search.Trim().ToLowerInvariant()}%";

            // CA1304 / CA1311 : ces appels ne s'exécutent pas en .NET. Ils sont traduits
            // en `lower()` par le fournisseur ; passer une CultureInfo rendrait au
            // contraire l'expression intraduisible.
#pragma warning disable CA1304, CA1311
            source = source.Where(u =>
                EF.Functions.Like(u.DisplayName.ToLower(), motif)
                || (u.Email != null && EF.Functions.Like(u.Email.ToLower(), motif)));
#pragma warning restore CA1304, CA1311
        }

        var total = await source.CountAsync(cancellationToken).ConfigureAwait(false);

        var lignes = await source
            .OrderByDescending(u => u.CreatedAt)
            .Skip((page - 1) * taille)
            .Take(taille)
            .Select(u => new
            {
                Utilisateur = u,
                Sessions = db.Sessions.Count(s =>
                    s.UserId == u.Id && s.RevokedAt == null && s.ExpiresAt > clock.UtcNow),
            })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return new UserPage(
            [.. lignes.Select(l => Map(l.Utilisateur, l.Sessions, 0))],
            total,
            page,
            taille);
    }

    public async Task<Result<UserRecord>> GetAsync(Guid userId, CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var ligne = await db.Users
            .Where(u => u.Id == userId)
            .Select(u => new
            {
                Utilisateur = u,
                Sessions = db.Sessions.Count(s =>
                    s.UserId == u.Id && s.RevokedAt == null && s.ExpiresAt > maintenant),
            })
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        return ligne is null ? AccountService.NotFound : Map(ligne.Utilisateur, ligne.Sessions, 0);
    }

    public async Task<Result> SuspendAsync(Guid userId, string reason, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(reason))
        {
            // Motif obligatoire : le journal d'audit doit rester exploitable des mois
            // plus tard (EF-ADM-06, RG-ADM-06).
            return DomainError.Validation("admin.reason_required", "Le motif est obligatoire.");
        }

        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        var maintenant = clock.UtcNow;
        utilisateur.SuspendedAt = maintenant;
        utilisateur.SuspensionReason = reason.Trim()[..Math.Min(500, reason.Trim().Length)];

        // RG-ADM-07 : la suspension révoque immédiatement les sessions. Sans cela, la
        // personne resterait connectée jusqu'à l'expiration de son jeton.
        var sessions = await db.Sessions
            .Where(s => s.UserId == userId && s.RevokedAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var session in sessions)
        {
            session.RevokedAt = maintenant;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<Result> UnsuspendAsync(Guid userId, CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        utilisateur.SuspendedAt = null;
        utilisateur.SuspensionReason = null;
        utilisateur.FailedLoginCount = 0;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public Task<Result> AnonymizeAsync(Guid userId, CancellationToken cancellationToken) =>
        deletion.AnonymizeAsync(userId, cancellationToken);

    public async Task<Result> ChangePlatformRoleAsync(
        Guid userId,
        PlatformRole role,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        // RG-ADM-04 : un rôle plateforme exige la double authentification. La refuser
        // ici plutôt que d'y remédier plus tard évite l'état transitoire où un compte
        // détient tous les droits sans second facteur.
        if (role != PlatformRole.User && utilisateur.TotpEnabledAt is null)
        {
            return DomainError.Rule(
                "admin.totp_required",
                "Ce compte doit d'abord activer la double authentification.");
        }

        // RG-ADM-03 : ne jamais laisser l'instance sans administrateur.
        if (utilisateur.PlatformRole == PlatformRole.PlatformAdmin && role != PlatformRole.PlatformAdmin)
        {
            var restants = await db.Users
                .CountAsync(
                    u => u.PlatformRole == PlatformRole.PlatformAdmin
                         && u.DeletedAt == null
                         && u.Id != userId,
                    cancellationToken)
                .ConfigureAwait(false);

            if (restants == 0)
            {
                return DomainError.Rule(
                    "admin.last_platform_admin",
                    "C'est le dernier administrateur : promouvoir un remplaçant d'abord.");
            }
        }

        utilisateur.PlatformRole = role;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<Result<int>> RevokeAllSessionsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var existe = await db.Users.AnyAsync(u => u.Id == userId, cancellationToken).ConfigureAwait(false);
        if (!existe)
        {
            return AccountService.NotFound;
        }

        var maintenant = clock.UtcNow;

        var sessions = await db.Sessions
            .Where(s => s.UserId == userId && s.RevokedAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var session in sessions)
        {
            session.RevokedAt = maintenant;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return sessions.Count;
    }

    public async Task<Result> MarkEmailVerifiedAsync(Guid userId, CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        utilisateur.EmailVerifiedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public Task<int> CountByPlatformRoleAsync(PlatformRole role, CancellationToken cancellationToken) =>
        db.Users.CountAsync(u => u.PlatformRole == role && u.DeletedAt == null, cancellationToken);

    public async Task<InstanceMetrics> GetMetricsAsync(CancellationToken cancellationToken)
    {
        // Indicateurs d'instance uniquement : des décomptes, jamais de contenu
        // d'événement (EF-ADM-10, RG-ADM-01).
        var comptes = await db.Users
            .Where(u => u.DeletedAt == null)
            .GroupBy(_ => 1)
            .Select(g => new
            {
                Total = g.Count(),
                Suspendus = g.Count(u => u.SuspendedAt != null),
                Personnel = g.Count(u => u.PlatformRole != PlatformRole.User),
                Verifies = g.Count(u => u.EmailVerifiedAt != null),
            })
            .FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        var evenements = await events.CountAsync(cancellationToken).ConfigureAwait(false);

        return new InstanceMetrics(
            comptes?.Total ?? 0,
            comptes?.Suspendus ?? 0,
            comptes?.Personnel ?? 0,
            comptes?.Verifies ?? 0,
            evenements.Total,
            evenements.Active,
            evenements.GuestMembers);
    }

    public Task<Result<string>> ExportAsync(Guid userId, CancellationToken cancellationToken) =>
        deletion.ExportAsync(userId, cancellationToken);

    public Task<Result> RemoveAvatarAsync(Guid userId, CancellationToken cancellationToken) =>
        accounts.DeleteAvatarAsync(userId, cancellationToken);

    private IQueryable<User> Vivant(Guid userId) =>
        db.Users.Where(u => u.Id == userId && u.DeletedAt == null);

    private static UserRecord Map(User u, int sessions, int evenements) => new(
        u.Id,
        u.Email,
        u.DisplayName,
        u.AvatarUrl,
        u.PlatformRole,
        u.EmailVerifiedAt is not null,
        u.PasswordHash is not null,
        u.TotpEnabledAt is not null,
        u.GoogleSubject is not null,
        u.AppleSubject is not null,
        u.SuspendedAt is not null,
        u.SuspensionReason,
        u.LastLoginAt,
        evenements,
        sessions,
        u.CreatedAt,
        u.DeletedAt);
}
