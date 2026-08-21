namespace PartyPlan.SharedKernel.Abstractions;

using PartyPlan.SharedKernel.Enums;

/// <summary>
/// Compte utilisateur de la requête courante.
/// </summary>
public interface ICurrentUser
{
    /// <summary>Identifiant du compte, absent lorsque l'appelant n'est pas authentifié.</summary>
    Guid? UserId { get; }

    PlatformRole PlatformRole { get; }

    bool IsAuthenticated { get; }

    /// <summary>
    /// Vrai pour un rôle plateforme. N'accorde aucun droit sur le contenu d'un
    /// événement : voir RG-ADM-01.
    /// </summary>
    bool IsPlatformStaff => PlatformRole is PlatformRole.Support or PlatformRole.PlatformAdmin;
}
