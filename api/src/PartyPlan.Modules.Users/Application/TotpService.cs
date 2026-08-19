namespace PartyPlan.Modules.Users.Application;

using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>Éléments d'enrôlement remis au client (EF-AUTH-12).</summary>
public sealed record TotpEnrollment(string Secret, string OtpAuthUri);

/// <summary>Résultat d'une activation : les codes de secours, affichés une seule fois.</summary>
public sealed record TotpActivation(IReadOnlyList<string> RecoveryCodes);

/// <summary>
/// Double authentification par code temporel (EF-AUTH-12, RG-ADM-04).
/// <para>
/// Le secret est chiffré au repos et non haché : sa vérification exige de le relire en
/// clair. L'activation n'a lieu qu'après qu'un premier code a été validé — enregistrer
/// l'activation avant preuve de fonctionnement enfermerait l'utilisateur dehors si son
/// application avait mal lu le QR code.
/// </para>
/// </summary>
public sealed class TotpService(
    IUsersDbContext db,
    IPasswordHasher hasher,
    ISecretProtector protector,
    ITotpCodes codes,
    IOptions<TotpIssuerOptions> issuer,
    IClock clock,
    IIdGenerator ids)
{
    public static readonly DomainError AlreadyEnabled = DomainError.Conflict(
        "totp.already_enabled",
        "La double authentification est déjà active.");

    public static readonly DomainError NotEnrolled = DomainError.Validation(
        "totp.not_enrolled",
        "Commence par générer un secret avant de l'activer.");

    public static readonly DomainError InvalidCode = DomainError.Validation(
        "totp.invalid_code",
        "Ce code est incorrect. Vérifie l'heure de ton téléphone, puis réessaie.");

    public static readonly DomainError NotEnabled = DomainError.Validation(
        "totp.not_enabled",
        "La double authentification n'est pas active sur ce compte.");

    public static readonly DomainError RequiredForPlatformRole = DomainError.Rule(
        "totp.required_for_platform_role",
        "Un rôle plateforme exige la double authentification : elle ne peut pas être retirée.");

    /// <summary>
    /// Prépare un enrôlement. Le secret est enregistré mais l'activation reste nulle :
    /// tant qu'un code n'a pas été validé, la connexion ne demande aucun second facteur.
    /// </summary>
    public async Task<Result<TotpEnrollment>> BeginEnrollmentAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        if (utilisateur.TotpEnabledAt is not null)
        {
            return AlreadyEnabled;
        }

        var secret = codes.GenerateSecret();
        utilisateur.TotpSecretEncrypted = protector.Protect(secret);

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return new TotpEnrollment(
            codes.ToBase32(secret),
            codes.BuildUri(
                issuer.Value.Name,
                utilisateur.Email ?? utilisateur.Id.ToString(),
                secret));
    }

    public async Task<Result<TotpActivation>> ActivateAsync(
        Guid userId,
        string code,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        if (utilisateur.TotpEnabledAt is not null)
        {
            return AlreadyEnabled;
        }

        if (!protector.TryUnprotect(utilisateur.TotpSecretEncrypted, out var secret))
        {
            return NotEnrolled;
        }

        if (!codes.Verify(secret, code, clock.UtcNow))
        {
            return InvalidCode;
        }

        utilisateur.TotpEnabledAt = clock.UtcNow;

        var codesDeSecours = await RegenerateRecoveryCodesAsync(userId, cancellationToken)
            .ConfigureAwait(false);

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return new TotpActivation(codesDeSecours);
    }

    /// <summary>
    /// Désactive la double authentification. Le mot de passe est exigé : sans cela, un
    /// jeton volé suffirait à retirer le second facteur, ce qui annulerait sa raison
    /// d'être.
    /// </summary>
    public async Task<Result> DisableAsync(
        Guid userId,
        string password,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        if (utilisateur.TotpEnabledAt is null)
        {
            return NotEnabled;
        }

        if (!hasher.Verify(password, utilisateur.PasswordHash))
        {
            return AccountService.WrongPassword;
        }

        // RG-ADM-04 : un rôle plateforme ne peut pas se passer du second facteur.
        if (utilisateur.PlatformRole != SharedKernel.Enums.PlatformRole.User)
        {
            return RequiredForPlatformRole;
        }

        utilisateur.TotpEnabledAt = null;
        utilisateur.TotpSecretEncrypted = null;

        await SupprimerCodesAsync(userId, cancellationToken).ConfigureAwait(false);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>Vérifie un code temporel, ou à défaut un code de secours consommé.</summary>
    public async Task<bool> VerifyAsync(
        Guid userId,
        string code,
        CancellationToken cancellationToken)
    {
        var utilisateur = await Vivant(userId).FirstOrDefaultAsync(cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur?.TotpEnabledAt is null)
        {
            return false;
        }

        if (protector.TryUnprotect(utilisateur.TotpSecretEncrypted, out var secret)
            && codes.Verify(secret, code, clock.UtcNow))
        {
            return true;
        }

        return await ConsumeRecoveryCodeAsync(userId, code, cancellationToken)
            .ConfigureAwait(false);
    }

    public Task<int> CountAvailableRecoveryCodesAsync(Guid userId, CancellationToken cancellationToken) =>
        db.TotpRecoveryCodes.CountAsync(c => c.UserId == userId && c.UsedAt == null, cancellationToken);

    /// <summary>
    /// Régénère le lot de codes de secours et renvoie les valeurs en clair. Elles ne
    /// seront plus jamais lisibles : seul leur condensé est conservé.
    /// </summary>
    public async Task<IReadOnlyList<string>> RegenerateRecoveryCodesAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        await SupprimerCodesAsync(userId, cancellationToken).ConfigureAwait(false);

        var lot = new List<string>(TotpRecoveryCode.BatchSize);

        for (var i = 0; i < TotpRecoveryCode.BatchSize; i++)
        {
            var code = GenerateRecoveryCode();
            lot.Add(code);

            db.TotpRecoveryCodes.Add(new TotpRecoveryCode
            {
                Id = ids.NewId(),
                UserId = userId,
                CodeHash = Hash(code),
                CreatedAt = clock.UtcNow,
            });
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return lot;
    }

    /// <summary>
    /// Format <c>XXXX-XXXX</c> sur un alphabet sans ambiguïté : ces codes sont recopiés
    /// à la main, souvent depuis une feuille de papier.
    /// </summary>
    private static string GenerateRecoveryCode()
    {
        const string alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var caracteres = new char[9];

        for (var i = 0; i < 9; i++)
        {
            caracteres[i] = i == 4 ? '-' : alphabet[RandomNumberGenerator.GetInt32(alphabet.Length)];
        }

        return new string(caracteres);
    }

    private static string Hash(string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Normalize(code))));

    private static string Normalize(string code) =>
        code.Replace(" ", string.Empty, StringComparison.Ordinal)
            .ToUpper(CultureInfo.InvariantCulture);

    private async Task<bool> ConsumeRecoveryCodeAsync(
        Guid userId,
        string code,
        CancellationToken cancellationToken)
    {
        var condense = Hash(code);

        var enregistre = await db.TotpRecoveryCodes
            .FirstOrDefaultAsync(
                c => c.UserId == userId && c.CodeHash == condense && c.UsedAt == null,
                cancellationToken)
            .ConfigureAwait(false);

        if (enregistre is null)
        {
            return false;
        }

        // Usage unique : un code de secours réutilisable perdrait tout intérêt s'il
        // était intercepté.
        enregistre.UsedAt = clock.UtcNow;
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return true;
    }

    private async Task SupprimerCodesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var existants = await db.TotpRecoveryCodes
            .Where(c => c.UserId == userId)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        db.TotpRecoveryCodes.RemoveRange(existants);
    }

    private IQueryable<Domain.User> Vivant(Guid userId) =>
        db.Users.Where(u => u.Id == userId && u.DeletedAt == null);
}

/// <summary>Nom d'émetteur affiché par les applications d'authentification.</summary>
public sealed class TotpIssuerOptions
{
    public const string SectionName = "Totp";

    public string Name { get; set; } = "PartyPlan";
}
