namespace PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Génération des identifiants. UUID v7 : ordonnés dans le temps, donc indexables
/// efficacement, sans divulguer de séquence exploitable (§7.1).
/// </summary>
public interface IIdGenerator
{
    Guid NewId();
}

public sealed class UuidV7Generator : IIdGenerator
{
    public Guid NewId() => Guid.CreateVersion7();
}
