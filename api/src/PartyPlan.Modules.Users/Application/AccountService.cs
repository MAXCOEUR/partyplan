namespace PartyPlan.Modules.Users.Application;

using System.Net;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Profil renvoyé à son titulaire.</summary>
public sealed record MyProfile(
    Guid Id,
    string? Email,
    bool EmailVerified,
    string DisplayName,
    string? AvatarUrl,
    string Locale,
    string Timezone,
    string PlatformRole,
    bool HasPassword,
    bool TotpEnabled,
    bool MustChangePassword,
    DateTimeOffset? PremiumUntil,
    DateTimeOffset CreatedAt);

/// <summary>Session active, telle que présentée à son titulaire (EF-AUTH-10).</summary>
public sealed record MySession(
    Guid Id,
    string? DeviceLabel,
    string? IpAddress,
    DateTimeOffset CreatedAt,
    DateTimeOffset LastSeenAt,
    bool IsCurrent);

/// <summary>
/// Gestion de son propre compte : profil, adresse, mot de passe, sessions, export,
/// suppression (EF-USR-01 à EF-USR-10).
/// </summary>
public sealed class AccountService(
    IUsersDbContext db,
    IPasswordHasher hasher,
    IPasswordPolicy policy,
    ITokenService tokens,
    IEmailSender email,
    IAvatarStorage avatars,
    IClock clock,
    IIdGenerator ids) : IPasswordResetTrigger
{
    /// <summary>
    /// Implémentation du contrat consommé par l'administration (EF-ADM-04). Le mot de
    /// passe n'est jamais choisi par l'administrateur : seul un lien part vers l'adresse
    /// enregistrée (RG-ADM-02).
    /// </summary>
    public Task SendResetLinkAsync(string emailAddress, CancellationToken cancellationToken) =>
        RequestPasswordResetAsync(emailAddress, null, requestedByAdmin: true, cancellationToken);

    /// <summary>Demandes de réinitialisation autorisées par adresse et par heure (RG-AUTH-05).</summary>
    public const int MaxResetRequestsPerHour = 5;

    public static readonly DomainError NotFound = DomainError.NotFound(
        "user.not_found",
        "Ce compte est introuvable.");

    public static readonly DomainError WrongPassword = DomainError.Validation(
        "user.wrong_password",
        "Le mot de passe actuel est incorrect.");

    public static readonly DomainError EmailAlreadyUsed = DomainError.Conflict(
        "user.email_already_used",
        "Cette adresse est déjà utilisée.");

    public static readonly DomainError InvalidToken = DomainError.Validation(
        "user.invalid_token",
        "Ce lien est invalide ou a expiré. Demande-en un nouveau.");

    public static readonly DomainError ConfirmationMismatch = DomainError.Validation(
        "user.confirmation_mismatch",
        "L'adresse saisie ne correspond pas à celle du compte.");

    public static readonly DomainError LastAdmin = DomainError.Rule(
        "user.last_platform_admin",
        "Tu es le dernier administrateur : transfère ce rôle avant de supprimer ton compte.");

    // ---------------------------------------------------------------- profil ----

    public async Task<Result<MyProfile>> GetProfileAsync(Guid userId, CancellationToken cancellationToken)
    {
        var utilisateur = await Find(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);

        return utilisateur is null ? NotFound : Map(utilisateur);
    }

    public async Task<Result<MyProfile>> UpdateProfileAsync(
        Guid userId,
        string? displayName,
        string? locale,
        string? timezone,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Find(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return NotFound;
        }

        if (displayName is not null)
        {
            var nom = displayName.Trim();
            if (nom.Length is 0 or > 120)
            {
                return DomainError.Validation(
                    "user.display_name_invalid",
                    "Le nom affiché doit contenir entre 1 et 120 caractères.");
            }

            // Le nom est libre, mais le fil d'activité conserve celui utilisé au moment
            // de chaque action (RG-USR-04) : personne ne se dissocie d'une dette en se
            // renommant.
            utilisateur.DisplayName = nom;
        }

        if (!string.IsNullOrWhiteSpace(locale))
        {
            utilisateur.Locale = locale.Trim()[..Math.Min(10, locale.Trim().Length)];
        }

        if (!string.IsNullOrWhiteSpace(timezone))
        {
            if (!TimeZoneInfo.TryFindSystemTimeZoneById(timezone, out _))
            {
                return DomainError.Validation("user.timezone_invalid", "Ce fuseau horaire est inconnu.");
            }

            utilisateur.Timezone = timezone;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Map(utilisateur);
    }

    // ------------------------------------------------------- mot de passe ----

    public async Task<Result> ChangePasswordAsync(
        Guid userId,
        string currentPassword,
        string newPassword,
        Guid? currentSessionId,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Find(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return NotFound;
        }

        // Un compte sans mot de passe — créé par connexion tierce — passe par le
        // parcours de réinitialisation (RG-AUTH-08), non par ici.
        if (!hasher.Verify(currentPassword, utilisateur.PasswordHash))
        {
            return WrongPassword;
        }

        var validation = policy.Validate(newPassword);
        if (validation.IsFailure)
        {
            return validation;
        }

        utilisateur.PasswordHash = hasher.Hash(newPassword);
        utilisateur.PasswordChangedAt = clock.UtcNow;
        utilisateur.MustChangePassword = false;

        await RevokeOtherSessionsAsync(userId, currentSessionId, cancellationToken).ConfigureAwait(false);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Demande de réinitialisation. La réponse est identique que l'adresse existe ou non
    /// (RG-AUTH-04) : le résultat renvoyé est donc toujours un succès.
    /// </summary>
    public async Task RequestPasswordResetAsync(
        string emailAddress,
        IPAddress? ip,
        bool requestedByAdmin,
        CancellationToken cancellationToken)
    {
        var normalise = AuthenticationService.Normalize(emailAddress);

        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Email == normalise && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return;
        }

        // RG-AUTH-08 : un compte créé par connexion tierce n'a pas de mot de passe. Le
        // parcours de réinitialisation est précisément son moyen d'en définir un — il ne
        // doit donc pas exiger qu'il en ait déjà un.

        // RG-AUTH-05 : cinq demandes par adresse et par heure. Le décompte est tenu ici,
        // et non par le limiteur de débit HTTP : celui-ci partitionne sur l'adresse IP et
        // ne protégerait pas un compte harcelé depuis plusieurs sources. Le dépassement
        // est silencieux, la réponse de l'endpoint étant de toute façon invariable
        // (RG-AUTH-04).
        var depuisUneHeure = clock.UtcNow.AddHours(-1);

        var demandesRecentes = await db.PasswordResetTokens
            .CountAsync(t => t.UserId == utilisateur.Id && t.CreatedAt >= depuisUneHeure, cancellationToken)
            .ConfigureAwait(false);

        if (demandesRecentes >= MaxResetRequestsPerHour)
        {
            return;
        }

        // Les demandes précédentes sont invalidées : un seul lien vivant à la fois
        // (RG-AUTH-03).
        await InvalidatePendingResetsAsync(utilisateur.Id, cancellationToken).ConfigureAwait(false);

        var secret = tokens.CreateOneTimeSecret();

        db.PasswordResetTokens.Add(new PasswordResetToken
        {
            Id = ids.NewId(),
            UserId = utilisateur.Id,
            TokenHash = secret.Hash,
            ExpiresAt = secret.ExpiresAt,
            RequestedIp = ip,
            RequestedByAdmin = requestedByAdmin,
            CreatedAt = clock.UtcNow,
        });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var origine = requestedByAdmin
            ? "Cette réinitialisation a été déclenchée par un administrateur de PartyPlan."
            : "Si tu n'as rien demandé, ignore ce message : ton mot de passe reste inchangé.";

        await email.SendAsync(
            new EmailMessage(
                utilisateur.Email!,
                "Réinitialise ton mot de passe — PartyPlan",
                $"""
                Bonjour {utilisateur.DisplayName},

                Voici ton code de réinitialisation :

                    {secret.Value}

                Il est valable 15 minutes et ne fonctionne qu'une seule fois.

                {origine}
                """),
            cancellationToken).ConfigureAwait(false);
    }

    public async Task<Result> ResetPasswordAsync(
        string token,
        string newPassword,
        CancellationToken cancellationToken)
    {
        var validation = policy.Validate(newPassword);
        if (validation.IsFailure)
        {
            return validation;
        }

        var condense = tokens.HashRefreshToken(token);
        var maintenant = clock.UtcNow;

        var jeton = await db.PasswordResetTokens
            .FirstOrDefaultAsync(t => t.TokenHash == condense, cancellationToken)
            .ConfigureAwait(false);

        if (jeton is null || !jeton.IsUsable(maintenant))
        {
            return InvalidToken;
        }

        var utilisateur = await Find(jeton.UserId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return InvalidToken;
        }

        jeton.ConsumedAt = maintenant;
        utilisateur.PasswordHash = hasher.Hash(newPassword);
        utilisateur.PasswordChangedAt = maintenant;
        utilisateur.MustChangePassword = false;
        utilisateur.FailedLoginCount = 0;

        // RG-AUTH-06 : une réinitialisation révoque toutes les sessions. Si le mot de
        // passe a été réinitialisé parce qu'un tiers y avait accès, laisser ses sessions
        // ouvertes annulerait l'effet de l'opération.
        await RevokeOtherSessionsAsync(utilisateur.Id, null, cancellationToken).ConfigureAwait(false);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    // ------------------------------------------------------------ adresse ----

    public async Task<Result> RequestEmailChangeAsync(
        Guid userId,
        string newEmail,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Find(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return NotFound;
        }

        var normalise = AuthenticationService.Normalize(newEmail);

        if (await db.Users.AnyAsync(u => u.Email == normalise && u.DeletedAt == null, cancellationToken)
                .ConfigureAwait(false))
        {
            return EmailAlreadyUsed;
        }

        var secret = tokens.CreateOneTimeSecret();

        db.EmailVerificationTokens.Add(new EmailVerificationToken
        {
            Id = ids.NewId(),
            UserId = userId,
            TokenHash = secret.Hash,
            NewEmail = normalise,
            ExpiresAt = secret.ExpiresAt,
            RequestedIp = ip,
            CreatedAt = clock.UtcNow,
        });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Le courriel part vers la nouvelle adresse : la vérifier est précisément
        // l'objet de l'opération (EF-USR-03).
        await email.SendAsync(
            new EmailMessage(
                normalise,
                "Confirme ta nouvelle adresse — PartyPlan",
                $"""
                Bonjour {utilisateur.DisplayName},

                Confirme cette adresse pour qu'elle devienne celle de ton compte :

                    {secret.Value}

                Valable 15 minutes. Tant que tu n'as pas confirmé, ton ancienne adresse
                reste active.
                """),
            cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<Result> ConfirmEmailAsync(string token, CancellationToken cancellationToken)
    {
        var condense = tokens.HashRefreshToken(token);
        var maintenant = clock.UtcNow;

        var jeton = await db.EmailVerificationTokens
            .FirstOrDefaultAsync(t => t.TokenHash == condense, cancellationToken)
            .ConfigureAwait(false);

        if (jeton is null || !jeton.IsUsable(maintenant))
        {
            return InvalidToken;
        }

        var utilisateur = await Find(jeton.UserId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return InvalidToken;
        }

        jeton.ConsumedAt = maintenant;

        if (jeton.NewEmail is not null)
        {
            if (await db.Users.AnyAsync(
                    u => u.Email == jeton.NewEmail && u.DeletedAt == null && u.Id != utilisateur.Id,
                    cancellationToken).ConfigureAwait(false))
            {
                return EmailAlreadyUsed;
            }

            utilisateur.Email = jeton.NewEmail;

            // RG-AUTH-06 : changer d'adresse révoque les sessions. L'adresse est le
            // point d'entrée de la réinitialisation ; sa modification doit couper les
            // accès existants.
            await RevokeOtherSessionsAsync(utilisateur.Id, null, cancellationToken).ConfigureAwait(false);
        }

        utilisateur.EmailVerifiedAt = maintenant;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    // ----------------------------------------------------------- sessions ----

    public async Task<IReadOnlyList<MySession>> ListSessionsAsync(
        Guid userId,
        Guid? currentSessionId,
        CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var sessions = await db.Sessions
            .Where(s => s.UserId == userId && s.RevokedAt == null && s.ExpiresAt > maintenant)
            .OrderByDescending(s => s.LastSeenAt)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        return
        [
            .. sessions.Select(s => new MySession(
                s.Id,
                s.DeviceLabel,
                s.IpAddress?.ToString(),
                s.CreatedAt,
                s.LastSeenAt,
                s.Id == currentSessionId)),
        ];
    }

    public async Task<Result> RevokeSessionAsync(
        Guid userId,
        Guid sessionId,
        CancellationToken cancellationToken)
    {
        var session = await db.Sessions
            .FirstOrDefaultAsync(s => s.Id == sessionId && s.UserId == userId, cancellationToken)
            .ConfigureAwait(false);

        if (session is null)
        {
            return DomainError.NotFound("session.not_found", "Cette session est introuvable.");
        }

        session.RevokedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    public async Task<int> RevokeOtherSessionsAsync(
        Guid userId,
        Guid? keepSessionId,
        CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var sessions = await db.Sessions
            .Where(s => s.UserId == userId
                        && s.RevokedAt == null
                        && (keepSessionId == null || s.Id != keepSessionId))
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var session in sessions)
        {
            session.RevokedAt = maintenant;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return sessions.Count;
    }

    // -------------------------------------------------------------- photo ----

    public async Task<Result<string>> SetAvatarAsync(
        Guid userId,
        Stream content,
        string contentType,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Find(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return NotFound;
        }

        var stockage = await avatars.StoreAsync(userId, content, contentType, cancellationToken)
            .ConfigureAwait(false);

        if (stockage.IsFailure)
        {
            return stockage.Error!;
        }

        utilisateur.AvatarUrl = stockage.Value;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return stockage.Value;
    }

    public async Task<Result> DeleteAvatarAsync(Guid userId, CancellationToken cancellationToken)
    {
        var utilisateur = await Find(userId).FirstOrDefaultAsync(cancellationToken).ConfigureAwait(false);
        if (utilisateur is null)
        {
            return NotFound;
        }

        await avatars.DeleteAsync(userId, cancellationToken).ConfigureAwait(false);

        // L'avatar par défaut est reconstruit localement à partir des initiales
        // (RG-USR-02) : il n'y a rien à remettre en place.
        utilisateur.AvatarUrl = null;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    private IQueryable<User> Find(Guid userId) =>
        db.Users.Where(u => u.Id == userId && u.DeletedAt == null);

    private async Task InvalidatePendingResetsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var maintenant = clock.UtcNow;

        var jetons = await db.PasswordResetTokens
            .Where(t => t.UserId == userId && t.ConsumedAt == null && t.ExpiresAt > maintenant)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var jeton in jetons)
        {
            jeton.ConsumedAt = maintenant;
        }
    }

    private static MyProfile Map(User u) => new(
        u.Id,
        u.Email,
        u.EmailVerifiedAt is not null,
        u.DisplayName,
        u.AvatarUrl,
        u.Locale,
        u.Timezone,
        u.PlatformRole.ToString(),
        u.PasswordHash is not null,
        u.TotpEnabledAt is not null,
        u.MustChangePassword,
        u.PremiumUntil,
        u.CreatedAt);
}
