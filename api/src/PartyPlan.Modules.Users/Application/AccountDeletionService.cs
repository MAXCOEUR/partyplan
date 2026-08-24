namespace PartyPlan.Modules.Users.Application;

using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Suppression de compte et export des données (EF-USR-09, EF-USR-10).
/// <para>
/// La suppression <b>anonymise</b> plutôt qu'elle n'efface (RG-RGPD-01, RG-USR-05) :
/// supprimer réellement une ligne détruirait la comptabilité d'événements auxquels
/// d'autres personnes participent, et rendrait leurs propres soldes faux. Le compte
/// devient « Ancien participant », son adresse est libérée, et ses contributions
/// financières subsistent.
/// </para>
/// </summary>
public sealed class AccountDeletionService(
    IUsersDbContext db,
    IAvatarStorage avatars,
    IClock clock)
{
    public const string AnonymousDisplayName = "Ancien participant";

    private static readonly JsonSerializerOptions ExportFormat = new() { WriteIndented = true };

    public async Task<Result> DeleteAsync(
        Guid userId,
        string emailConfirmation,
        CancellationToken cancellationToken)
    {
        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Id == userId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        // Confirmation par saisie de l'adresse : la suppression est irréversible et
        // touche des données financières partagées (RG-USR-05).
        if (!string.Equals(
                utilisateur.Email?.Trim(),
                emailConfirmation?.Trim(),
                StringComparison.OrdinalIgnoreCase))
        {
            return AccountService.ConfirmationMismatch;
        }

        // RG-ADM-03 : le dernier administrateur de plateforme ne peut pas disparaître,
        // sans quoi l'instance devient ingérable.
        if (utilisateur.PlatformRole == PlatformRole.PlatformAdmin)
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
                return AccountService.LastAdmin;
            }
        }

        await AnonymizeAsync(utilisateur.Id, cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Anonymise un compte. Utilisé par l'auto-suppression comme par l'administration
    /// (EF-ADM-07), afin que les deux chemins produisent exactement le même état.
    /// </summary>
    public async Task<Result> AnonymizeAsync(Guid userId, CancellationToken cancellationToken)
    {
        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Id == userId && u.DeletedAt == null, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        var maintenant = clock.UtcNow;

        await avatars.DeleteAsync(userId, cancellationToken).ConfigureAwait(false);

        // L'adresse est libérée : une réinscription ultérieure crée un compte neuf,
        // sans lien avec l'ancien (RG-USR-06).
        utilisateur.Email = null;
        utilisateur.EmailVerifiedAt = null;
        utilisateur.PasswordHash = null;
        utilisateur.GoogleSubject = null;
        utilisateur.AppleSubject = null;
        utilisateur.AvatarUrl = null;
        utilisateur.DisplayName = AnonymousDisplayName;
        utilisateur.PlatformRole = PlatformRole.User;
        utilisateur.DeletedAt = maintenant;

        var sessions = await db.Sessions
            .Where(s => s.UserId == userId && s.RevokedAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var session in sessions)
        {
            session.RevokedAt = maintenant;
        }

        // Les jetons en attente deviennent inutilisables : un lien de réinitialisation
        // survivant à la suppression permettrait de reprendre la main sur le compte.
        var jetonsMdp = await db.PasswordResetTokens
            .Where(t => t.UserId == userId && t.ConsumedAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var jetonsAdresse = await db.EmailVerificationTokens
            .Where(t => t.UserId == userId && t.ConsumedAt == null)
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        foreach (var jeton in jetonsMdp)
        {
            jeton.ConsumedAt = maintenant;
        }

        foreach (var jeton in jetonsAdresse)
        {
            jeton.ConsumedAt = maintenant;
        }

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);

        return Result.Success();
    }

    /// <summary>
    /// Export complet au format JSON (EF-USR-09, EF-RGPD-01). Sans intervention
    /// humaine : c'est l'exigence, un export sur demande par courriel ne la satisfait pas.
    /// </summary>
    public async Task<Result<string>> ExportAsync(Guid userId, CancellationToken cancellationToken)
    {
        var utilisateur = await db.Users
            .FirstOrDefaultAsync(u => u.Id == userId, cancellationToken)
            .ConfigureAwait(false);

        if (utilisateur is null)
        {
            return AccountService.NotFound;
        }

        var sessions = await db.Sessions
            .Where(s => s.UserId == userId)
            .Select(s => new
            {
                s.DeviceLabel,
                Adresse = s.IpAddress == null ? null : s.IpAddress.ToString(),
                s.CreatedAt,
                s.LastSeenAt,
                s.ExpiresAt,
                s.RevokedAt,
            })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var groupes = await db.Groups
            .Where(g => g.OwnerUserId == userId)
            .Select(g => new { g.Name, g.CreatedAt })
            .ToListAsync(cancellationToken)
            .ConfigureAwait(false);

        var export = new
        {
            genereLe = clock.UtcNow,
            avertissement =
                "Ce fichier contient les données de ton compte. Les dépenses et "
                + "remboursements d'un événement appartiennent à l'événement : ils sont "
                + "exportables depuis celui-ci.",
            compte = new
            {
                utilisateur.Id,
                utilisateur.Email,
                utilisateur.DisplayName,
                utilisateur.Locale,
                utilisateur.Timezone,
                role = utilisateur.PlatformRole.ToString(),
                adresseVerifiee = utilisateur.EmailVerifiedAt,
                motDePasseDefini = utilisateur.PasswordHash is not null,
                connexionGoogle = utilisateur.GoogleSubject is not null,
                connexionApple = utilisateur.AppleSubject is not null,
                utilisateur.LastLoginAt,
                utilisateur.CreatedAt,
                utilisateur.DeletedAt,
            },
            sessions,
            groupes,
        };

        return JsonSerializer.Serialize(export, ExportFormat);
    }
}
