namespace PartyPlan.UnitTests;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>Horloge que le test avance à la main. Le temps réel rendrait le cache intestable.</summary>
internal sealed class HorlogeDeTest : IClock
{
    public DateTimeOffset UtcNow { get; private set; } =
        new(2026, 8, 24, 20, 0, 0, TimeSpan.Zero);

    internal void Avancer(TimeSpan duree) => UtcNow = UtcNow.Add(duree);
}
