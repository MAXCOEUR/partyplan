namespace PartyPlan.Infrastructure.Persistence;

using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Implémentation à portée requête du périmètre d'événements. Non thread-safe par
/// construction : une instance sert une seule requête.
/// </summary>
public sealed class EventScope : IEventScope
{
    private Guid[] _allowed = [];
    private readonly List<Guid> _temporary = [];

    public Guid[] AllowedEventIds => _temporary.Count == 0
        ? _allowed
        : [.. _allowed, .. _temporary];

    public bool IsPrimed { get; private set; }

    public void Prime(IEnumerable<Guid> eventIds)
    {
        ArgumentNullException.ThrowIfNull(eventIds);

        _allowed = [.. eventIds.Distinct()];
        IsPrimed = true;
    }

    public IDisposable AllowTemporarily(Guid eventId)
    {
        _temporary.Add(eventId);
        return new Revoker(this, eventId);
    }

    private sealed class Revoker(EventScope scope, Guid eventId) : IDisposable
    {
        private bool _disposed;

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            scope._temporary.Remove(eventId);
            _disposed = true;
        }
    }
}
