namespace PartyPlan.Modules.Users.Application;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;

/// <summary>Paramètres d'amorçage du premier administrateur.</summary>
public sealed class AdminSeedSettings
{
    public const string SectionName = "Admin";

    /// <summary>Longueur minimale, alignée sur RG-AUTH-01.</summary>
    public const int MinPasswordLength = 12;

    public string? Email { get; set; }

    public string? Password { get; set; }
}

/// <summary>
/// Amorçage du premier administrateur de plateforme (EF-ADM-01, RG-ADM-09 à RG-ADM-12).
/// <para>
/// Placé dans le module Users, seul propriétaire de la table des comptes. Idempotent :
/// si un administrateur existe déjà, rien n'est fait et le mot de passe d'amorçage n'est
/// jamais réappliqué — sans quoi chaque redémarrage annulerait le changement de mot de
/// passe imposé par RG-ADM-10.
/// </para>
/// </summary>
public sealed class AdminSeeder(
    IUsersDbContext db,
    IPasswordHasher hasher,
    IAuditLog audit,
    IOptions<AdminSeedSettings> settings,
    IClock clock,
    IIdGenerator ids,
    ILogger<AdminSeeder> logger)
{
    public async Task<bool> SeedAsync(CancellationToken cancellationToken)
    {
        var existant = await db.Users
            .AnyAsync(
                u => u.PlatformRole == PlatformRole.PlatformAdmin && u.DeletedAt == null,
                cancellationToken)
            .ConfigureAwait(false);

        if (existant)
        {
            logger.LogInformation(
                "Un administrateur de plateforme existe déjà : amorçage ignoré (RG-ADM-09).");
            return false;
        }

        var parametres = settings.Value;

        // RG-ADM-11 : plutôt qu'un démarrage silencieux avec un identifiant par défaut,
        // l'application refuse de démarrer et dit ce qui manque.
        if (string.IsNullOrWhiteSpace(parametres.Email)
            || string.IsNullOrWhiteSpace(parametres.Password)
            || parametres.Password.Length < AdminSeedSettings.MinPasswordLength)
        {
            throw new InvalidOperationException(
                "Aucun administrateur de plateforme n'existe et l'amorçage est incomplet. "
                + $"Renseigner {AdminSeedSettings.SectionName}:Email et un "
                + $"{AdminSeedSettings.SectionName}:Password de "
                + $"{AdminSeedSettings.MinPasswordLength} caractères minimum (RG-ADM-11). "
                + "Voir infra/compose/.env.example.");
        }

        var adresse = parametres.Email.Trim();

        // Une adresse déjà présente sur un compte ordinaire est promue plutôt que
        // dupliquée : l'unicité de l'adresse est une contrainte de base.
        var compte = await db.Users
            .FirstOrDefaultAsync(u => u.Email == adresse && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        var creation = compte is null;

        if (compte is null)
        {
            compte = new User
            {
                Id = ids.NewId(),
                Email = adresse,
                DisplayName = "Administrateur",
            };

            db.Users.Add(compte);
        }

        compte.PasswordHash = hasher.Hash(parametres.Password);
        compte.PasswordChangedAt = clock.UtcNow;
        compte.PlatformRole = PlatformRole.PlatformAdmin;

        // RG-ADM-10 : changement de mot de passe imposé à la première connexion. Le mot
        // de passe d'amorçage figure dans un fichier de configuration, donc lisible par
        // quiconque accède au serveur.
        compte.MustChangePassword = true;
        compte.EmailVerifiedAt ??= clock.UtcNow;

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        // Le mot de passe n'apparaît jamais dans les journaux (RG-AUTH-02).
        logger.LogWarning(
            "Administrateur de plateforme amorcé pour {Adresse}. Changement de mot de passe "
            + "imposé à la première connexion ; retirer ensuite ADMIN_PASSWORD de "
            + "l'environnement (RG-ADM-12).",
            adresse);

        await audit.RecordSystemAsync(
            AdminAuditActions.AdminSeeded,
            compte.Id,
            new { adresse, creation },
            cancellationToken).ConfigureAwait(false);

        return true;
    }
}
