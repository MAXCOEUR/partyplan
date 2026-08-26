namespace PartyPlan.IntegrationTests.Infrastructure;

using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.SharedKernel.Contracts;
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

    /// <summary>
    /// Diffusions temps réel enregistrées à la place d'être émises.
    /// <para>
    /// Observer un vrai hub depuis un test d'intégration exigerait un client SignalR et
    /// une connexion : ce qui nous appartient, et donc ce qui se teste, est de savoir si
    /// le service publie et avec quoi. Le transport est celui du framework.
    /// </para>
    /// <para>
    /// Les tests d'une collection xUnit s'exécutent en série : chacun vide la liste
    /// avant d'agir.
    /// </para>
    /// </summary>
    public DiffusionEnregistree Diffusions { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ConfigureServices(services =>
        {
            // La doublure enregistre **et** relaie vers la vraie diffusion SignalR.
            // Enregistrer seulement suffisait tant qu'on vérifiait que les services
            // publient ; prouver qu'un abonné reçoit exige que la diffusion parte pour
            // de bon.
            services.RemoveAll<IDiffusionEvenement>();
            services.AddSingleton<IDiffusionEvenement>(sp =>
            {
                Diffusions.Interne ??= ActivatorUtilities
                    .CreateInstance<PartyPlan.Infrastructure.TempsReel.DiffusionSignalR>(sp);

                return Diffusions;
            });
        });
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
                // Les tests partagent une seule adresse IP : une limite pensée pour un
                // utilisateur unique les ferait échouer les uns à cause des autres. La
                // limitation est vérifiée par la recette, contre une API réelle.
                ["RateLimiting:Enabled"] = "false",
                // L'ordonnanceur est éteint : une passe déclenchée sous les tests
                // planifierait ce qu'ils n'ont pas demandé, et les rendrait dépendants
                // du moment où ils tournent. Ceux qui l'éprouvent appellent PasseAsync.
                ["Notifications:Ordonnanceur:Enabled"] = "false",
                ["Database:MigrateOnStartup"] = "true",
                ["Database:SeedDemoData"] = "false",
            }));

        return base.CreateHost(builder);
    }
}

/// <summary>Diffusion qui enregistre au lieu d'émettre.</summary>
public sealed class DiffusionEnregistree : IDiffusionEvenement
{
    private readonly List<(Guid Evenement, string Message, object Charge)> _publications = [];

    /// <summary>
    /// Diffusion réelle, vers laquelle relayer après enregistrement.
    /// <para>
    /// Posée par la fabrique au premier accès plutôt qu'au constructeur : la fixture est
    /// créée avant l'hôte, donc avant qu'un <c>IHubContext</c> existe.
    /// </para>
    /// </summary>
    public IDiffusionEvenement? Interne { get; set; }

    public IReadOnlyList<(Guid Evenement, string Message, object Charge)> Publications
    {
        get
        {
            lock (_publications)
            {
                return [.. _publications];
            }
        }
    }

    public void Clear()
    {
        lock (_publications)
        {
            _publications.Clear();
        }
    }

    public Task PublierAsync(
        Guid eventId,
        string message,
        object charge,
        CancellationToken cancellationToken)
    {
        lock (_publications)
        {
            _publications.Add((eventId, message, charge));
        }

        return Interne?.PublierAsync(eventId, message, charge, cancellationToken)
            ?? Task.CompletedTask;
    }
}

/// <summary>Collection partagée : un seul conteneur PostgreSQL pour l'ensemble des tests.</summary>
[CollectionDefinition(Name)]
public sealed class ApiTestSuite : ICollectionFixture<PartyPlanApiFixture>
{
    public const string Name = "api";
}
