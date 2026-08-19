namespace PartyPlan.Modules.Users.Application;

using System.Globalization;
using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Jetons remis à l'issue d'une authentification réussie.</summary>
public sealed record SessionTokens(
    string AccessToken,
    DateTimeOffset AccessTokenExpiresAt,
    string RefreshToken,
    DateTimeOffset RefreshTokenExpiresAt);

/// <summary>
/// Inscription, connexion, rafraîchissement et déconnexion.
/// <para>
/// Les échecs de connexion sont volontairement indistincts : adresse inconnue, mot de
/// passe erroné et compte inexistant renvoient la même erreur. Les distinguer
/// fournirait un oracle d'existence de comptes.
/// </para>
/// </summary>
public sealed class AuthenticationService(
    IUsersDbContext db,
    IPasswordHasher hasher,
    IPasswordPolicy policy,
    ITokenService tokens,
    IEmailSender email,
    IClock clock,
    IIdGenerator ids,
    ILogger<AuthenticationService> logger)
{
    /// <summary>Nombre d'échecs consécutifs à partir duquel les tentatives ralentissent (RG-AUTH-05).</summary>
    public const int SlowdownThreshold = 10;

    /// <summary>Empreinte factice, de coût identique à une vraie, pour égaliser les temps de réponse.</summary>
    private const string DecoyHash =
        "argon2id$65536$3$2$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

    public static readonly DomainError InvalidCredentials = DomainError.Validation(
        "auth.invalid_credentials",
        "Adresse e-mail ou mot de passe incorrect.");

    public static readonly DomainError EmailAlreadyUsed = DomainError.Conflict(
        "auth.email_already_used",
        "Un compte existe déjà avec cette adresse.");

    public static readonly DomainError InvalidRefreshToken = DomainError.Validation(
        "auth.invalid_refresh_token",
        "Ta session a expiré. Reconnecte-toi.");

    public static readonly DomainError AccountSuspended = DomainError.Forbidden(
        "auth.account_suspended",
        "Ce compte est suspendu. Contacte le support.");

    public static readonly DomainError DisplayNameRequired = DomainError.Validation(
        "auth.display_name_required",
        "Indique ton prénom.");

    public async Task<Result<SessionTokens>> RegisterAsync(
        string emailAddress,
        string password,
        string displayName,
        string? deviceLabel,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var normalise = Normalize(emailAddress);

        var validation = policy.Validate(password);
        if (validation.IsFailure)
        {
            return validation.Error!;
        }

        if (string.IsNullOrWhiteSpace(displayName))
        {
            return DisplayNameRequired;
        }

        var existe = await db.Users
            .AnyAsync(u => u.Email == normalise && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (existe)
        {
            return EmailAlreadyUsed;
        }

        var utilisateur = new User
        {
            Id = ids.NewId(),
            Email = normalise,
            DisplayName = displayName.Trim(),
            PasswordHash = hasher.Hash(password),
            PasswordChangedAt = clock.UtcNow,
        };

        db.Users.Add(utilisateur);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await SendVerificationAsync(utilisateur, ip, cancellationToken).ConfigureAwait(false);

        return await OpenSessionAsync(utilisateur, deviceLabel, ip, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<Result<SessionTokens>> LoginAsync(
        string emailAddress,
        string password,
        string? deviceLabel,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var normalise = Normalize(emailAddress);

        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Email == normalise && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            // Vérification factice : sans elle, l'absence de compte se reconnaîtrait au
            // temps de réponse, Argon2id étant délibérément lent.
            hasher.Verify(password, DecoyHash);
            return InvalidCredentials;
        }

        if (utilisateur.IsSuspended)
        {
            return AccountSuspended;
        }

        await SlowDownIfNeededAsync(utilisateur, cancellationToken).ConfigureAwait(false);

        if (!hasher.Verify(password, utilisateur.PasswordHash))
        {
            utilisateur.FailedLoginCount =
                (short)Math.Min(short.MaxValue, utilisateur.FailedLoginCount + 1);
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

            return InvalidCredentials;
        }

        // Réhachage silencieux si le coût a été relevé depuis la dernière connexion.
        if (hasher.NeedsRehash(utilisateur.PasswordHash))
        {
            utilisateur.PasswordHash = hasher.Hash(password);
        }

        utilisateur.FailedLoginCount = 0;
        utilisateur.LastLoginAt = clock.UtcNow;

        return await OpenSessionAsync(utilisateur, deviceLabel, ip, cancellationToken)
            .ConfigureAwait(false);
    }

    public async Task<Result<SessionTokens>> RefreshAsync(
        string refreshToken,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var condense = tokens.HashRefreshToken(refreshToken);
        var maintenant = clock.UtcNow;

        var session = await db.Sessions
            .FirstOrDefaultAsync(s => s.RefreshTokenHash == condense, cancellationToken)
            .ConfigureAwait(false);

        if (session is null || !session.IsActive(maintenant))
        {
            return InvalidRefreshToken;
        }

        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Id == session.UserId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null || utilisateur.IsSuspended)
        {
            return InvalidRefreshToken;
        }

        // Rotation : un jeton de rafraîchissement présenté deux fois ne fonctionne plus,
        // ce qui borne l'exploitation d'un vol.
        var rafraichissement = tokens.CreateRefreshToken();
        session.RefreshTokenHash = rafraichissement.Hash;
        session.LastSeenAt = maintenant;
        session.ExpiresAt = rafraichissement.ExpiresAt;
        session.IpAddress = ip ?? session.IpAddress;

        var acces = tokens.CreateAccessToken(utilisateur.Id, utilisateur.PlatformRole, session.Id);

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return new SessionTokens(
            acces.Value,
            acces.ExpiresAt,
            rafraichissement.Value,
            rafraichissement.ExpiresAt);
    }

    public async Task<Result> LogoutAsync(Guid sessionId, CancellationToken cancellationToken)
    {
        var session = await db.Sessions
            .FirstOrDefaultAsync(s => s.Id == sessionId, cancellationToken)
            .ConfigureAwait(false);

        if (session is not null && session.RevokedAt is null)
        {
            session.RevokedAt = clock.UtcNow;
            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
        }

        return Result.Success();
    }

    /// <summary>Normalise une adresse. La casse est gérée par <c>citext</c> ; les espaces non.</summary>
    public static string Normalize(string emailAddress) => emailAddress.Trim();

    private async Task<SessionTokens> OpenSessionAsync(
        User utilisateur,
        string? deviceLabel,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var rafraichissement = tokens.CreateRefreshToken();

        var session = new Session
        {
            Id = ids.NewId(),
            UserId = utilisateur.Id,
            RefreshTokenHash = rafraichissement.Hash,
            DeviceLabel = string.IsNullOrWhiteSpace(deviceLabel)
                ? null
                : deviceLabel[..Math.Min(120, deviceLabel.Length)],
            IpAddress = ip,
            CreatedAt = clock.UtcNow,
            LastSeenAt = clock.UtcNow,
            ExpiresAt = rafraichissement.ExpiresAt,
        };

        db.Sessions.Add(session);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        var acces = tokens.CreateAccessToken(utilisateur.Id, utilisateur.PlatformRole, session.Id);

        return new SessionTokens(
            acces.Value,
            acces.ExpiresAt,
            rafraichissement.Value,
            rafraichissement.ExpiresAt);
    }

    /// <summary>
    /// Ralentissement croissant après échecs répétés (RG-AUTH-05). Le compte n'est
    /// jamais verrouillé : un tiers pourrait sinon en priver son titulaire.
    /// </summary>
    private async Task SlowDownIfNeededAsync(User utilisateur, CancellationToken cancellationToken)
    {
        if (utilisateur.FailedLoginCount < SlowdownThreshold)
        {
            return;
        }

        var exces = utilisateur.FailedLoginCount - SlowdownThreshold + 1;
        var attente = TimeSpan.FromMilliseconds(Math.Min(5_000, 250 * exces));

        if (logger.IsEnabled(LogLevel.Warning))
        {
            logger.LogWarning(
                "Ralentissement de connexion : {Echecs} échecs consécutifs, attente {Attente} ms",
                utilisateur.FailedLoginCount,
                attente.TotalMilliseconds.ToString(CultureInfo.InvariantCulture));
        }

        await Task.Delay(attente, cancellationToken).ConfigureAwait(false);
    }

    private async Task SendVerificationAsync(
        User utilisateur,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var secret = tokens.CreateOneTimeSecret();

        db.EmailVerificationTokens.Add(new EmailVerificationToken
        {
            Id = ids.NewId(),
            UserId = utilisateur.Id,
            TokenHash = secret.Hash,
            ExpiresAt = secret.ExpiresAt,
            RequestedIp = ip,
            CreatedAt = clock.UtcNow,
        });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        await email.SendAsync(
            new EmailMessage(
                utilisateur.Email!,
                "Confirme ton adresse — PartyPlan",
                $"""
                Bonjour {utilisateur.DisplayName},

                Confirme ton adresse pour activer ton compte PartyPlan. Ton code :

                    {secret.Value}

                Il est valable 15 minutes et ne fonctionne qu'une seule fois.

                Si tu n'as pas créé de compte, ignore ce message.
                """),
            cancellationToken).ConfigureAwait(false);
    }
}
