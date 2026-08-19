namespace PartyPlan.Infrastructure.Persistence;

using System.Linq.Expressions;
using System.Reflection;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Construit les filtres globaux du modèle. Écrit une fois ici, plutôt que répété
/// dans chaque configuration d'entité : c'est l'exigence RG-SEC-02, qui interdit de
/// laisser le cloisonnement à la discrétion de chaque requête.
/// </summary>
internal static class QueryFilterBuilder
{
    private static readonly MethodInfo ContainsMethod = typeof(Enumerable)
        .GetMethods(BindingFlags.Public | BindingFlags.Static)
        .Single(m => m.Name == nameof(Enumerable.Contains)
                     && m.GetParameters().Length == 2)
        .MakeGenericMethod(typeof(Guid));

    /// <summary>
    /// Applique, pour chaque entité concernée, la conjonction de deux conditions :
    /// appartenance de l'événement au périmètre de l'appelant, et absence
    /// d'effacement logique.
    /// </summary>
    internal static void ApplyGlobalFilters(ModelBuilder modelBuilder, PartyPlanDbContext context)
    {
        // Accès au périmètre par une propriété du contexte : Entity Framework en fait
        // un paramètre de requête, réévalué à chaque exécution. Le modèle n'est donc
        // compilé qu'une fois, malgré un périmètre différent à chaque requête.
        var allowedIds = Expression.Property(
            Expression.Constant(context),
            nameof(PartyPlanDbContext.AllowedEventIds));

        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            var clrType = entityType.ClrType;
            var parameter = Expression.Parameter(clrType, "e");
            Expression? predicate = null;

            // L'événement lui-même est cloisonné sur sa clé primaire ; les entités
            // rattachées le sont sur leur colonne event_id.
            var scopeProperty = clrType == typeof(Event)
                ? nameof(Event.Id)
                : typeof(IEventScoped).IsAssignableFrom(clrType) ? nameof(IEventScoped.EventId) : null;

            if (scopeProperty is not null)
            {
                predicate = Expression.Call(
                    ContainsMethod,
                    allowedIds,
                    Expression.Property(parameter, scopeProperty));
            }

            if (typeof(ISoftDeletable).IsAssignableFrom(clrType))
            {
                var notDeleted = Expression.Equal(
                    Expression.Property(parameter, nameof(ISoftDeletable.DeletedAt)),
                    Expression.Constant(null, typeof(DateTimeOffset?)));

                predicate = predicate is null ? notDeleted : Expression.AndAlso(predicate, notDeleted);
            }

            if (predicate is not null)
            {
                modelBuilder.Entity(clrType).HasQueryFilter(Expression.Lambda(predicate, parameter));
            }
        }
    }
}
