namespace PartyPlan.IntegrationTests.Infrastructure;

using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using PartyPlan.Infrastructure.Persistence;
using Testcontainers.PostgreSql;
using Xunit;

/// <summary>
/// Hôte de test complet : API réelle, base PostgreSQL réelle, migrations réelles.
/// <para>
/// Aucun substitut de base n'est utilisé. Un test de cloisonnement exécuté sur un
/// fournisseur en mémoire ne prouverait rien : ni les filtres traduits en SQL, ni les
/// index partiels, ni les déclencheurs d'ajout seul n'y existent.
/// </para>
/// </summary>
public sealed class PartyPlanApiFixture : WebApplicationFactory<Program>, IAsyncLifetime
{
    private readonly PostgreSqlContainer _database = new PostgreSqlBuilder("postgres:16-alpine")
        .WithDatabase("partyplan_tests")
        .WithUsername("partyplan")
        .WithPassword("partyplan")
        .Build();

    /// <summary>Clé de signature du test. Identique à celle injectée dans l'hôte.</summary>
    public const string SigningKey = "cle_de_test_uniquement_pour_les_tests_32c";

    public const string Issuer = "https://tests.partyplan.local";

    public const string Audience = "partyplan-app";

    // Implémentation explicite : WebApplicationFactory expose déjà un DisposeAsync
    // renvoyant ValueTask, incompatible avec la signature attendue par xUnit.
    async Task IAsyncLifetime.InitializeAsync()
    {
        await _database.StartAsync().ConfigureAwait(false);

        // Force la construction de l'hôte et l'application des migrations.
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PartyPlanDbContext>();
        await db.Database.MigrateAsync().ConfigureAwait(false);
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync().ConfigureAwait(false);
        await _database.DisposeAsync().ConfigureAwait(false);
    }

    /// <summary>Exécute une action sur la base sans aucun filtre de cloisonnement, pour préparer un jeu de données.</summary>
    public async Task WithDatabaseAsync(Func<PartyPlanDbContext, Task> action)
    {
        ArgumentNullException.ThrowIfNull(action);

        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PartyPlanDbContext>();
        await action(db).ConfigureAwait(false);
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.UseEnvironment("Development");

        builder.ConfigureHostConfiguration(config =>
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Default"] = _database.GetConnectionString(),
                ["Jwt:SigningKey"] = SigningKey,
                ["Jwt:Issuer"] = Issuer,
                ["Jwt:Audience"] = Audience,
                ["Admin:Email"] = "admin@partyplan.test",
                ["Admin:Password"] = "MotDePasseDeTest2026",
                ["Database:MigrateOnStartup"] = "true",
                ["Database:SeedDemoData"] = "false",
            }));

        return base.CreateHost(builder);
    }
}

/// <summary>Collection partagée : un seul conteneur PostgreSQL pour l'ensemble des tests.</summary>
[CollectionDefinition(Name)]
public sealed class ApiTestSuite : ICollectionFixture<PartyPlanApiFixture>
{
    public const string Name = "api";
}
