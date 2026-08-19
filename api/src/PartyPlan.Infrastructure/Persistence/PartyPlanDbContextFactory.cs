namespace PartyPlan.Infrastructure.Persistence;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using PartyPlan.SharedKernel.Abstractions;

/// <summary>
/// Fabrique utilisée par les outils Entity Framework (<c>dotnet ef migrations</c>).
/// Elle ne sert jamais à l'exécution : le périmètre fourni est vide, ce qui est correct
/// pour la seule génération du schéma.
/// </summary>
public sealed class PartyPlanDbContextFactory : IDesignTimeDbContextFactory<PartyPlanDbContext>
{
    public PartyPlanDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__Default")
            ?? "Host=localhost;Port=5433;Database=partyplan;Username=partyplan;Password=partyplan";

        var options = new DbContextOptionsBuilder<PartyPlanDbContext>()
            .UseNpgsql(connectionString)
            .Options;

        var emptyScope = new EventScope();
        emptyScope.Prime([]);

        return new PartyPlanDbContext(options, emptyScope, new SystemClock(), new UuidV7Generator());
    }
}
