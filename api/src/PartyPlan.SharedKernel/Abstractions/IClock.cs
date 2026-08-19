namespace PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Horloge injectée. Aucun appel direct à <c>DateTimeOffset.UtcNow</c> dans le domaine :
/// sans cette indirection, les règles temporelles (fin implicite à +12 h, expiration
/// des jetons, plage de silence des notifications) ne sont pas testables.
/// </summary>
public interface IClock
{
    /// <summary>Instant courant, toujours en UTC (§7.1).</summary>
    DateTimeOffset UtcNow { get; }
}

public sealed class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}
