namespace PartyPlan.SharedKernel.Contracts;

using PartyPlan.SharedKernel.Enums;
using PartyPlan.SharedKernel.Primitives;

/// <summary>
/// Contrat public du module Users, seul propriétaire de la table des comptes.
/// <para>
/// Placé dans le SharedKernel et non dans le module Users : deux modules ne se
/// référencent jamais directement (ADR 0002). Le SharedKernel sert de registre de
/// contrats, ce qui laisse la frontière vérifiable par l'outil
/// <c>verifier-frontieres-modules.sh</c>. Règle attachée : ce répertoire ne contient
/// que des interfaces et des types de données, jamais de logique, et chaque contrat
/// nomme son module propriétaire.
/// </para>
/// </summary>
public interface IUserDirectory
{
    /// <summary>Recherche paginée, destinée au back-office (EF-ADM-02).</summary>
    Task<UserPage> SearchAsync(UserQuery query, CancellationToken cancellationToken);

    /// <summary>Fiche technique d'un compte. Ne contient aucune donnée d'événement (RG-ADM-01).</summary>
    Task<Result<UserRecord>> GetAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result> SuspendAsync(Guid userId, string reason, CancellationToken cancellationToken);

    Task<Result> UnsuspendAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>Anonymise le compte plutôt que de l'effacer (RG-RGPD-01, RG-USR-05).</summary>
    Task<Result> AnonymizeAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result> ChangePlatformRoleAsync(Guid userId, PlatformRole role, CancellationToken cancellationToken);

    Task<Result<int>> RevokeAllSessionsAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result> MarkEmailVerifiedAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>Nombre de comptes portant un rôle plateforme donné. Support de RG-ADM-03.</summary>
    Task<int> CountByPlatformRoleAsync(PlatformRole role, CancellationToken cancellationToken);

    /// <summary>Indicateurs d'instance (EF-ADM-10).</summary>
    Task<InstanceMetrics> GetMetricsAsync(CancellationToken cancellationToken);

    /// <summary>
    /// Export des données d'un compte, à sa demande, lorsqu'il ne peut plus se connecter
    /// (EF-ADM-12). Même contenu que l'export en libre-service : l'administrateur n'a pas
    /// accès à davantage.
    /// </summary>
    Task<Result<string>> ExportAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>Supprime une photo de profil signalée comme inappropriée (EF-ADM-13).</summary>
    Task<Result> RemoveAvatarAsync(Guid userId, CancellationToken cancellationToken);

    /// <summary>
    /// Fixe ou retire l'échéance de la formule payante (EF-PRM-04, ADR 0008).
    /// <para>
    /// Une échéance nulle vaut retour à la formule gratuite. Le résultat porte l'ancienne
    /// valeur et dit si quelque chose a changé : c'est l'appelant qui décide d'écrire au
    /// journal d'audit, et une réapplication à l'identique ne doit rien y laisser.
    /// </para>
    /// </summary>
    Task<Result<PlanChange>> SetPlanAsync(
        Guid userId,
        DateTimeOffset? premiumUntil,
        CancellationToken cancellationToken);
}

/// <summary>
/// Effet d'un changement de formule. <paramref name="Changed"/> distingue un octroi réel
/// d'une réapplication sans effet.
/// </summary>
public sealed record PlanChange(
    DateTimeOffset? Previous,
    DateTimeOffset? Current,
    bool Changed);

public sealed record UserQuery(string? Search, int Page, int PageSize, bool IncludeDeleted = false);

public sealed record UserPage(IReadOnlyList<UserRecord> Items, int Total, int Page, int PageSize);

/// <summary>
/// Vue d'un compte pour l'administration. Volontairement limitée aux données techniques
/// nécessaires au support (RG-RGPD-04) : ni contenu d'événement, ni empreinte de mot de
/// passe.
/// </summary>
public sealed record UserRecord(
    Guid Id,
    string? Email,
    string DisplayName,
    string? AvatarUrl,
    PlatformRole PlatformRole,
    bool EmailVerified,
    bool HasPassword,
    bool GoogleLinked,
    bool AppleLinked,
    bool IsSuspended,
    string? SuspensionReason,
    DateTimeOffset? LastLoginAt,
    int EventCount,
    int ActiveSessionCount,
    DateTimeOffset CreatedAt,
    DateTimeOffset? DeletedAt);

public sealed record InstanceMetrics(
    int TotalUsers,
    int SuspendedUsers,
    int PlatformStaff,
    int VerifiedUsers,
    int TotalEvents,
    int ActiveEvents,
    int GuestMembers);
