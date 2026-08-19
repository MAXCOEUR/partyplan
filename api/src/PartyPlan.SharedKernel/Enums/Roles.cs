namespace PartyPlan.SharedKernel.Enums;

/// <summary>
/// Rôle de portée « instance entière » (§3.1). Sans rapport avec <see cref="EventMemberRole"/> :
/// un <see cref="PlatformAdmin"/> n'a aucun droit dans un événement dont il n'est pas membre.
/// </summary>
public enum PlatformRole
{
    User = 0,
    Support = 1,
    PlatformAdmin = 2,
}

/// <summary>Rôle de portée « un seul événement » (§3.2).</summary>
public enum EventMemberRole
{
    Member = 0,
    Admin = 1,
    Owner = 2,
}

/// <summary>Statut de présence (EF-PRES-01). Le statut initial est <see cref="Unknown"/> : RG-PRES-01.</summary>
public enum EventMemberStatus
{
    Unknown = 0,
    Going = 1,
    Maybe = 2,
    NotGoing = 3,

    /// <summary>Arrive plus tard. Compté comme présent : RG-PRES-02.</summary>
    Late = 4,

    /// <summary>Part plus tôt. Compté comme présent : RG-PRES-02.</summary>
    EarlyLeave = 5,
}

/// <summary>Catégorie d'article de la liste de courses (EF-CRS-02).</summary>
public enum ShoppingCategory
{
    Drinks = 0,
    Food = 1,
    Supplies = 2,
    Other = 3,
}
