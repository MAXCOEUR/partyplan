namespace PartyPlan.Modules.Users.Application;

using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// État d'un fournisseur tiers pour un compte donné (EF-AUTH-08).
/// <para>
/// <paramref name="Configured"/> et <paramref name="Linked"/> sont indépendants : un
/// fournisseur peut être rattaché à un compte alors que l'instance n'a plus de clé, et
/// il doit alors rester détachable.
/// </para>
/// </summary>
/// <param name="Provider">Identifiant du fournisseur, en minuscules.</param>
/// <param name="Configured">Vrai si cette instance dispose des clés nécessaires.</param>
/// <param name="Linked">Vrai si ce compte est rattaché à ce fournisseur.</param>
public sealed record ProviderState(string Provider, bool Configured, bool Linked);

/// <summary>
/// Moyens de connexion d'un compte (EF-AUTH-08).
/// <para>
/// Le sujet transmis par le fournisseur n'est jamais exposé : l'écran n'en a pas besoin,
/// et une réponse d'API ne porte pas d'identifiant tiers.
/// </para>
/// </summary>
public sealed record SignInMethods(bool HasPassword, IReadOnlyList<ProviderState> Providers);

/// <summary>
/// Connexion par fournisseur tiers (EF-AUTH-06, EF-AUTH-07, EF-AUTH-08).
/// <para>
/// Le rattachement se fait sur le sujet du fournisseur, jamais sur l'adresse : une
/// adresse change, le sujet non. L'adresse ne sert qu'à retrouver un compte existant, et
/// seulement si le fournisseur atteste l'avoir vérifiée.
/// </para>
/// </summary>
public sealed class ExternalSignInService(
    IUsersDbContext db,
    IExternalIdentityVerifier verifier,
    AuthenticationService sessions,
    IClock clock,
    IIdGenerator ids,
    ILogger<ExternalSignInService> logger)
{
    public static readonly DomainError EmailRequired = DomainError.Rule(
        "external.email_required",
        "Ce service n'a pas communiqué d'adresse e-mail vérifiée. Crée un compte avec "
        + "ton adresse et un mot de passe.");

    public static readonly DomainError AlreadyLinkedElsewhere = DomainError.Conflict(
        "external.already_linked",
        "Ce compte externe est déjà rattaché à un autre compte PartyPlan.");

    public static readonly DomainError NotLinked = DomainError.Validation(
        "external.not_linked",
        "Aucun compte de ce service n'est rattaché.");

    public static readonly DomainError WouldLockOut = DomainError.Rule(
        "external.would_lock_out",
        "C'est ton seul moyen de connexion : définis d'abord un mot de passe.");

    /// <summary>
    /// Connexion ou inscription par fournisseur tiers.
    /// <para>
    /// La double authentification s'applique aussi à ce chemin : un compte qui l'a
    /// activée reçoit un défi, sans quoi la connexion tierce serait une porte de
    /// contournement.
    /// </para>
    /// </summary>
    public async Task<Result<LoginOutcome>> SignInAsync(
        string provider,
        string idToken,
        string? deviceLabel,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        var identite = await verifier.VerifyAsync(provider, idToken, cancellationToken)
            .ConfigureAwait(false);

        if (identite.IsFailure)
        {
            return identite.Error!;
        }

        var sujet = identite.Value.Subject;

        var existant = await TrouverParSujetAsync(provider, sujet, cancellationToken)
            .ConfigureAwait(false);

        if (existant is not null)
        {
            return await OuvrirAsync(existant, deviceLabel, ip, cancellationToken)
                .ConfigureAwait(false);
        }

        // Sans adresse vérifiée par le fournisseur, ni rattachement ni création : un
        // compte sans adresse fiable ne pourrait ni exporter ses données, ni récupérer
        // son accès.
        if (string.IsNullOrWhiteSpace(identite.Value.Email) || !identite.Value.EmailVerified)
        {
            return EmailRequired;
        }

        var adresse = identite.Value.Email.Trim();

        var parAdresse = await db.Users
            .FirstOrDefaultAsync(u => u.Email == adresse && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (parAdresse is not null)
        {
            // Rattachement à un compte existant. Ce n'est pas une élévation de
            // privilège : le fournisseur atteste que la personne contrôle cette boîte,
            // et quiconque la contrôle peut déjà réinitialiser le mot de passe.
            Rattacher(parAdresse, provider, sujet);
            parAdresse.EmailVerifiedAt ??= clock.UtcNow;

            await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

            logger.LogInformation(
                "Connexion {Fournisseur} rattachée à un compte existant.",
                provider);

            return await OuvrirAsync(parAdresse, deviceLabel, ip, cancellationToken)
                .ConfigureAwait(false);
        }

        var nouveau = new User
        {
            Id = ids.NewId(),
            Email = adresse,
            DisplayName = string.IsNullOrWhiteSpace(identite.Value.DisplayName)
                ? adresse.Split('@')[0]
                : identite.Value.DisplayName.Trim(),
            // L'adresse est vérifiée par le fournisseur : redemander une confirmation
            // serait une friction sans bénéfice.
            EmailVerifiedAt = clock.UtcNow,
        };

        Rattacher(nouveau, provider, sujet);
        db.Users.Add(nouveau);

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        logger.LogInformation("Compte créé par connexion {Fournisseur}.", provider);

        return await OuvrirAsync(nouveau, deviceLabel, ip, cancellationToken).ConfigureAwait(false);
    }

    /// <summary>Rattache un fournisseur à un compte déjà connecté (EF-AUTH-08).</summary>
    public async Task<Result> LinkAsync(
        Guid userId,
        string provider,
        string idToken,
        CancellationToken cancellationToken)
    {
        var identite = await verifier.VerifyAsync(provider, idToken, cancellationToken)
            .ConfigureAwait(false);

        if (identite.IsFailure)
        {
            return identite.Error!;
        }

        var deja = await TrouverParSujetAsync(provider, identite.Value.Subject, cancellationToken)
            .ConfigureAwait(false);

        if (deja is not null)
        {
            return deja.Id == userId ? Result.Success() : AlreadyLinkedElsewhere;
        }

        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Id == userId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        Rattacher(utilisateur, provider, identite.Value.Subject);
        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Détache un fournisseur (EF-AUTH-08).
    /// <para>
    /// Refusé si c'est le dernier moyen de connexion : détacher enfermerait la personne
    /// hors de son propre compte, sans recours puisqu'une réinitialisation de mot de
    /// passe suppose déjà un mot de passe à réinitialiser.
    /// </para>
    /// </summary>
    public async Task<Result> UnlinkAsync(
        Guid userId,
        string provider,
        CancellationToken cancellationToken)
    {
        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Id == userId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        var rattachements = new List<string>();
        if (utilisateur.GoogleSubject is not null)
        {
            rattachements.Add(ExternalProviders.Google);
        }

        if (utilisateur.AppleSubject is not null)
        {
            rattachements.Add(ExternalProviders.Apple);
        }

        if (!rattachements.Contains(Normaliser(provider), StringComparer.Ordinal))
        {
            return NotLinked;
        }

        var moyensRestants = rattachements.Count - 1
                             + (utilisateur.PasswordHash is not null ? 1 : 0);

        if (moyensRestants == 0)
        {
            return WouldLockOut;
        }

        switch (Normaliser(provider))
        {
            case ExternalProviders.Google:
                utilisateur.GoogleSubject = null;
                break;
            case ExternalProviders.Apple:
                utilisateur.AppleSubject = null;
                break;
            default:
                return NotLinked;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Moyens de connexion du compte, pour l'écran de rattachement (EF-AUTH-08).
    /// </summary>
    public async Task<Result<SignInMethods>> GetMethodsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var utilisateur = await db.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        return new SignInMethods(
            utilisateur.PasswordHash is not null,
            [
                new ProviderState(
                    ExternalProviders.Google,
                    verifier.IsConfigured(ExternalProviders.Google),
                    utilisateur.GoogleSubject is not null),
                new ProviderState(
                    ExternalProviders.Apple,
                    verifier.IsConfigured(ExternalProviders.Apple),
                    utilisateur.AppleSubject is not null),
            ]);
    }

    private static string Normaliser(string provider) => provider.ToLowerInvariant();

    private static void Rattacher(User utilisateur, string provider, string sujet)
    {
        switch (Normaliser(provider))
        {
            case ExternalProviders.Google:
                utilisateur.GoogleSubject = sujet;
                break;
            case ExternalProviders.Apple:
                utilisateur.AppleSubject = sujet;
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(provider), provider, "Fournisseur inconnu.");
        }
    }

    private Task<User?> TrouverParSujetAsync(
        string provider,
        string sujet,
        CancellationToken cancellationToken) =>
        Normaliser(provider) switch
        {
            ExternalProviders.Google => db.Users.FirstOrDefaultAsync(
                u => u.GoogleSubject == sujet && u.DeletedAt == null,
                cancellationToken),
            ExternalProviders.Apple => db.Users.FirstOrDefaultAsync(
                u => u.AppleSubject == sujet && u.DeletedAt == null,
                cancellationToken),
            _ => Task.FromResult<User?>(null),
        };

    private async Task<Result<LoginOutcome>> OuvrirAsync(
        User utilisateur,
        string? deviceLabel,
        IPAddress? ip,
        CancellationToken cancellationToken)
    {
        if (utilisateur.IsSuspended)
        {
            return AuthenticationService.AccountSuspended;
        }

        return await sessions
            .CompleteExternalSignInAsync(utilisateur.Id, deviceLabel, ip, cancellationToken)
            .ConfigureAwait(false);
    }
}
