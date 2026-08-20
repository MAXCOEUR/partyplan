namespace PartyPlan.SharedKernel.Contracts;

using Microsoft.AspNetCore.Builder;

/// <summary>
/// Marque un endpoint comme exigeant l'en-tête <c>Idempotency-Key</c> (§8.1).
/// <para>
/// Simple métadonnée, et non le filtre lui-même : celui-ci a besoin de la base, donc
/// vit dans l'Infrastructure, qu'un module ne référence jamais (ADR 0002). Le module
/// déclare l'exigence, l'hôte branche le mécanisme.
/// </para>
/// </summary>
public sealed class IdempotencyRequirement;

public static class IdempotencyRequirementExtensions
{
    /// <summary>
    /// Exige l'idempotence. À appliquer à toute création dont le doublon aurait des
    /// conséquences financières, ou produirait un objet visible que l'utilisateur devrait
    /// ensuite nettoyer.
    /// </summary>
    public static RouteHandlerBuilder RequireIdempotency(this RouteHandlerBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        return builder.WithMetadata(new IdempotencyRequirement());
    }
}
