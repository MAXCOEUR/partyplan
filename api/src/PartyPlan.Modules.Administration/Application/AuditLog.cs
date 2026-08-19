namespace PartyPlan.Modules.Administration.Application;

using System.Text.Json;
using PartyPlan.Modules.Administration.Domain;
using PartyPlan.Modules.Administration.Persistence;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Journal d'audit (RG-ADM-06).
/// <para>
/// En ajout seul : aucune méthode de modification ni de suppression n'existe, et la base
/// les refuse également par déclencheur (NF-SEC-08). Un administrateur ne peut donc pas
/// effacer la trace de ses propres actions, y compris avec un accès direct à la base.
/// </para>
/// </summary>
public sealed class AuditLog(
    IAdministrationDbContext db,
    ICurrentUser currentUser,
    IUserDirectory users,
    IClock clock,
    IIdGenerator ids,
    Microsoft.AspNetCore.Http.IHttpContextAccessor http) : IAuditLog
{
    /// <summary>Auteur conventionnel des actions sans intervention humaine.</summary>
    public static readonly Guid SystemActorId = Guid.Empty;

    public const string SystemActorEmail = "(système)";

    public async Task RecordAsync(
        string action,
        Guid? targetUserId,
        string? reason,
        object? metadata,
        CancellationToken cancellationToken)
    {
        var auteur = currentUser.UserId
            ?? throw new InvalidOperationException(
                "Une action d'administration ne peut pas être enregistrée sans auteur identifié.");

        // L'adresse de l'auteur est recopiée : le journal doit rester lisible après
        // suppression de son compte, et une jointure vers un compte anonymisé ne
        // dirait plus qui a agi.
        var fiche = await users.GetAsync(auteur, cancellationToken).ConfigureAwait(false);

        db.AdminAuditEntries.Add(new AdminAuditEntry
        {
            Id = ids.NewId(),
            ActorUserId = auteur,
            ActorEmail = fiche.IsSuccess ? fiche.Value.Email ?? "(sans adresse)" : "(compte introuvable)",
            TargetUserId = targetUserId,
            Action = action,
            Reason = reason,
            IpAddress = http.HttpContext?.Connection.RemoteIpAddress,
            Metadata = metadata is null ? null : JsonSerializer.Serialize(metadata),
            CreatedAt = clock.UtcNow,
        });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }

    public async Task RecordSystemAsync(
        string action,
        Guid? targetUserId,
        object? metadata,
        CancellationToken cancellationToken)
    {
        db.AdminAuditEntries.Add(new AdminAuditEntry
        {
            Id = ids.NewId(),
            ActorUserId = SystemActorId,
            ActorEmail = SystemActorEmail,
            TargetUserId = targetUserId,
            Action = action,
            Metadata = metadata is null ? null : JsonSerializer.Serialize(metadata),
            CreatedAt = clock.UtcNow,
        });

        await db.SaveChangesAsync(cancellationToken).ConfigureAwait(false);
    }
}
