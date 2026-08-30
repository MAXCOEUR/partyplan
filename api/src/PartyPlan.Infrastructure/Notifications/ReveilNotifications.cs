namespace PartyPlan.Infrastructure.Notifications;

using PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Signal de réveil. Un sémaphore borné à un jeton plutôt qu'une file : dix messages
/// simultanés doivent produire une passe d'envoi, pas dix.
/// </summary>
public sealed class ReveilNotifications : IReveilNotifications, IDisposable
{
    private readonly SemaphoreSlim _signal = new(0, 1);

    public void Reveiller()
    {
        // Le sémaphore est déjà armé : une passe est due, inutile d'en demander une
        // seconde. Release lèverait au-delà du plafond, d'où le try.
        try
        {
            _signal.Release();
        }
        catch (SemaphoreFullException)
        {
        }
    }

    internal Task<bool> AttendreAsync(TimeSpan delai, CancellationToken cancellationToken)
        => _signal.WaitAsync(delai, cancellationToken);

    public void Dispose() => _signal.Dispose();
}
