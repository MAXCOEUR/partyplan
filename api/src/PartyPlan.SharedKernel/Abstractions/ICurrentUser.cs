namespace PartyPlan.SharedKernel.Abstractions;

using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Appelant de la requête courante. Deux natures d'appelant coexistent :
/// un compte utilisateur, et un invité sans compte dont la portée est limitée
/// à un seul événement (EF-INV-04).
/// </summary>
public interface ICurrentUser
{
    /// <summary>Identifiant du compte, absent pour un invité sans compte.</summary>
    Guid? UserId { get; }

    /// <summary>
    /// Événement auquel un jeton d'invité est restreint. Toujours <c>null</c> pour
    /// un compte : un compte accède à tous ses événements.
    /// </summary>
    Guid? GuestEventId { get; }

    PlatformRole PlatformRole { get; }

    bool IsAuthenticated { get; }

    /// <summary>
    /// Vrai pour un rôle plateforme. N'accorde aucun droit sur le contenu d'un
    /// événement : voir RG-ADM-01.
    /// </summary>
    bool IsPlatformStaff => PlatformRole is PlatformRole.Support or PlatformRole.PlatformAdmin;
}
