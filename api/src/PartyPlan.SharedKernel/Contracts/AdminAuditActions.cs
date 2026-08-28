namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Codes d'action du journal d'audit. Ils font partie du contrat <see cref="IAuditLog"/>
/// et non du module qui possède la table : l'appelant doit pouvoir les nommer sans
/// référencer le module Administration (ADR 0002).
///
/// Chaîne stable : ne jamais renommer une valeur déjà écrite en base, le journal étant
/// en ajout seul et donc non corrigeable.
/// </summary>
public static class AdminAuditActions
{
    public const string PasswordResetTriggered = "user.password_reset_triggered";
    public const string SessionsRevoked = "user.sessions_revoked";
    public const string Suspended = "user.suspended";
    public const string Unsuspended = "user.unsuspended";
    public const string Deleted = "user.deleted";
    public const string RoleChanged = "user.role_changed";
    public const string EmailVerifiedByAdmin = "user.email_verified_by_admin";
    public const string DataExported = "user.data_exported";
    public const string AvatarRemoved = "user.avatar_removed";

    /// <summary>
    /// Changement de formule (EF-PRM-04). Une seule action pour l'octroi et le retrait :
    /// c'est le même geste, et la nouvelle échéance distingue l'un de l'autre. Deux
    /// constantes auraient obligé chaque lecteur du journal à savoir laquelle chercher.
    /// </summary>
    public const string PlanChanged = "user.plan_changed";
    public const string AdminSeeded = "admin.seeded";
}
