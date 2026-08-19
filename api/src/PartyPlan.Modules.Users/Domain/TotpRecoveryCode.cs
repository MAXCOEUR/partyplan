namespace PartyPlan.Modules.Users.Domain;

/// <summary>
/// Code de secours de la double authentification.
/// <para>
/// Indispensable, et absent du cahier des charges initial : sans code de secours, un
/// téléphone perdu enferme définitivement son titulaire hors de son compte, et la seule
/// issue serait une intervention en base. Pour un administrateur de plateforme, cela
/// rendrait l'instance ingérable.
/// </para>
/// <para>
/// Seul le condensé est stocké : les codes en clair ne sont affichés qu'une fois, à
/// l'activation.
/// </para>
/// </summary>
public sealed class TotpRecoveryCode
{
    /// <summary>Nombre de codes remis à l'activation.</summary>
    public const int BatchSize = 8;

    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string CodeHash { get; set; } = string.Empty;

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset? UsedAt { get; set; }

    public bool IsAvailable => UsedAt is null;
}
