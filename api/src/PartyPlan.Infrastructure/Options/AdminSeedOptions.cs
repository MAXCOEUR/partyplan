namespace PartyPlan.Infrastructure.Options;

using System.ComponentModel.DataAnnotations;

/// <summary>
/// Amorçage du premier administrateur (RG-ADM-09 à RG-ADM-12). La validation est
/// délibérément stricte : un démarrage silencieux avec un identifiant par défaut connu
/// serait la faille la plus évidente du produit (RG-ADM-11).
/// </summary>
public sealed class AdminSeedOptions
{
    public const string SectionName = "Admin";

    /// <summary>Longueur minimale exigée par RG-AUTH-01.</summary>
    public const int MinPasswordLength = 12;

    [EmailAddress]
    public string? Email { get; set; }

    public string? Password { get; set; }
}
