namespace PartyPlan.IntegrationTests;

using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Hosting;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Abstractions;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Testcontainers.PostgreSql;
using Xunit;

/// <summary>
/// Le réveil de l'expéditeur (tâche 3, docs/exploitation.md §1.2) : un service métier
/// réveille l'envoi après validation, sans attendre le tour d'horloge.
/// <para>
/// Ce test monte sa propre pile, ordonnanceur allumé : la pile partagée de la
/// collection « api » l'éteint (voir <see cref="PartyPlanApiFixture"/>), justement pour
/// que les autres tests ne dépendent pas du moment où ils tournent. Éprouver la boucle
/// réelle qui attend le réveil exige donc une pile à soi.
/// </para>
/// </summary>
public sealed class ReveilNotificationsTests
{
    [Fact]
    public async Task Le_reveil_envoie_sans_relancer_la_planification()
    {
        // Le réveil ne doit déclencher que la seconde passe : recalculer les rappels de
        // toutes les soirées à chaque message est un coût sans contrepartie.
        var planificateur = new PlanificateurCompteur();
        await using var pile = await PileAvecAsync(planificateur);

        await EnfilerNotificationImmediateAsync(pile);
        pile.Reveil.Reveiller();
        await pile.AttendreEnvoiAsync();

        pile.NotificationsParties.ShouldBe(1);
        planificateur.Appels.ShouldBe(0);
    }

    private static async Task<ReveilPile> PileAvecAsync(PlanificateurCompteur planificateur)
    {
        var pile = new ReveilPile(planificateur);
        await pile.DemarrerAsync();

        return pile;
    }

    /// <summary>
    /// Enfile une notification déjà due, pour un compte et une soirée à venir. La soirée
    /// existe pour que la distinction compte : une pleine passe régressée aurait de quoi
    /// planifier, et c'est justement ce que <see cref="PlanificateurCompteur"/> doit
    /// prouver ne pas s'être produit.
    /// </summary>
    private static async Task EnfilerNotificationImmediateAsync(ReveilPile pile)
    {
        var compte = Guid.CreateVersion7();
        var eventId = Guid.CreateVersion7();

        await pile.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new User
            {
                Id = compte,
                Email = $"reveil-{compte:N}@partyplan.test",
                DisplayName = "Camille",
                PasswordHash = "x",
                Timezone = "Europe/Paris",
                CreatedAt = DateTimeOffset.UtcNow,
            });

            db.Events.Add(new Event
            {
                Id = eventId,
                Name = "Soirée du réveil",
                StartsAt = ReveilPile.Maintenant.AddDays(1),
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = compte,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = Guid.CreateVersion7(),
                EventId = eventId,
                UserId = compte,
                DisplayName = "Camille",
                Role = EventMemberRole.Owner,
                Status = EventMemberStatus.Going,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            db.Notifications.Add(new Notification
            {
                Id = Guid.CreateVersion7(),
                UserId = compte,
                EventId = eventId,
                Category = NotificationCategories.DiscussionMessage,
                Title = "Titre",
                Body = "Corps",
                DeepLink = $"/events/{eventId}",
                ScheduledFor = ReveilPile.Maintenant.AddMinutes(-1),
                CreatedAt = ReveilPile.Maintenant.AddMinutes(-1),
                DedupKey = $"{eventId}:reveil:{compte}:{Guid.NewGuid():N}",
            });

            await db.SaveChangesAsync();
        });
    }
}

/// <summary>
/// Pile dédiée au réveil : ordonnanceur allumé, horloge figée en plein jour, et un
/// planificateur compté en plus des planificateurs réels du module Events.
/// </summary>
public sealed class ReveilPile : WebApplicationFactory<Program>
{
    /// <summary>18 h à Paris.</summary>
    public static readonly DateTimeOffset Maintenant = new(2026, 9, 12, 16, 0, 0, TimeSpan.Zero);

    private readonly PostgreSqlContainer _database = new PostgreSqlBuilder("postgres:16-alpine")
        .WithDatabase("partyplan_reveil_tests")
        .WithUsername("partyplan")
        .WithPassword("partyplan")
        .Build();

    private readonly PlanificateurCompteur _planificateur;

    private readonly SemaphoreSlim _envoiSignale = new(0, int.MaxValue);

    public ReveilPile(PlanificateurCompteur planificateur)
    {
        _planificateur = planificateur;
    }

    public IReveilNotifications Reveil { get; private set; } = null!;

    public int NotificationsParties { get; private set; }

    public async Task DemarrerAsync()
    {
        await _database.StartAsync().ConfigureAwait(false);

        // Force la construction de l'hôte et l'application des migrations, comme la
        // pile partagée.
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PartyPlanDbContext>();
        await db.Database.MigrateAsync().ConfigureAwait(false);

        Reveil = Services.GetRequiredService<IReveilNotifications>();
    }

    /// <summary>Exécute une action sur la base sans filtre de cloisonnement, pour préparer un jeu de données.</summary>
    public async Task WithDatabaseAsync(Func<PartyPlanDbContext, Task> action)
    {
        ArgumentNullException.ThrowIfNull(action);

        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PartyPlanDbContext>();
        await action(db).ConfigureAwait(false);
    }

    /// <summary>
    /// Attend le signal réel de la passe d'envoi — jamais un délai fixe : un délai puis
    /// un compte à zéro ne prouverait rien, ce test doit constater que l'envoi a bien eu
    /// lieu avant de juger le planificateur.
    /// </summary>
    public async Task AttendreEnvoiAsync()
    {
        var signale = await _envoiSignale.WaitAsync(TimeSpan.FromSeconds(15)).ConfigureAwait(false);

        if (!signale)
        {
            throw new TimeoutException(
                "La passe d'envoi réveillée n'a pas eu lieu dans le délai attendu.");
        }
    }

    internal void SignalerEnvoi(int envoyees)
    {
        NotificationsParties += envoyees;
        _envoiSignale.Release();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.ConfigureServices(services =>
        {
            // Horloge figée : le test attend un envoi immédiat, indépendant du moment
            // réel d'exécution.
            services.RemoveAll<IClock>();
            services.AddSingleton<IClock>(new HorlogeFixe(Maintenant));

            // Planificateur compté, en plus des planificateurs réels du module Events :
            // une régression qui relancerait la planification au réveil se verrait ici.
            services.AddSingleton(_planificateur);
            services.AddSingleton<IPlanificateurRappels>(sp =>
                sp.GetRequiredService<PlanificateurCompteur>());

            // La passe d'envoi réelle, observée : le test attend un signal, pas un délai.
            services.RemoveAll<IEnvoiNotifications>();
            services.AddScoped<IEnvoiNotifications>(sp =>
            {
                var reel = ActivatorUtilities
                    .CreateInstance<PartyPlan.Modules.Notifications.Application.EnvoiNotifications>(sp);

                return new EnvoiNotificationsObservee(reel, this);
            });
        });
    }

    protected override IHost CreateHost(IHostBuilder builder)
    {
        ArgumentNullException.ThrowIfNull(builder);

        builder.UseEnvironment("Development");

        builder.ConfigureHostConfiguration(config =>
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Default"] = _database.GetConnectionString(),
                ["Jwt:SigningKey"] = PartyPlanApiFixture.SigningKey,
                ["Jwt:Issuer"] = PartyPlanApiFixture.Issuer,
                ["Jwt:Audience"] = PartyPlanApiFixture.Audience,
                ["Admin:Email"] = "admin@partyplan.test",
                ["Admin:Password"] = "MotDePasseDeTest2026",
                ["RateLimiting:Enabled"] = "false",
                // Allumé, à l'inverse de la pile partagée : c'est la boucle réelle qui
                // attend le réveil que ce test éprouve.
                ["Notifications:Ordonnanceur:Enabled"] = "true",
                // Assez long pour ne jamais s'écouler pendant ce test : sans quoi une
                // passe complète naturelle pourrait s'intercaler et fausser le compte.
                ["Notifications:Ordonnanceur:Cadence"] = "00:30:00",
                ["Database:MigrateOnStartup"] = "true",
                ["Database:SeedDemoData"] = "false",
            }));

        return base.CreateHost(builder);
    }

    public override async ValueTask DisposeAsync()
    {
        await base.DisposeAsync().ConfigureAwait(false);
        await _database.DisposeAsync().ConfigureAwait(false);
    }
}

/// <summary>Décore l'envoi réel pour signaler la pile, sans en changer le comportement.</summary>
internal sealed class EnvoiNotificationsObservee(IEnvoiNotifications reel, ReveilPile pile)
    : IEnvoiNotifications
{
    public async Task<int> EnvoyerLesDuesAsync(
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        var envoyees = await reel
            .EnvoyerLesDuesAsync(maintenant, cancellationToken)
            .ConfigureAwait(false);

        pile.SignalerEnvoi(envoyees);

        return envoyees;
    }
}

/// <summary>Planificateur qui ne planifie rien, et compte seulement qu'on le lui ait demandé.</summary>
public sealed class PlanificateurCompteur : IPlanificateurRappels
{
    private int _appels;

    public int Appels => _appels;

    public Task PlanifierAsync(
        EvenementAVenir evenement,
        DateTimeOffset maintenant,
        CancellationToken cancellationToken)
    {
        Interlocked.Increment(ref _appels);

        return Task.CompletedTask;
    }
}

/// <summary>Horloge figée, pour ne jamais dépendre de l'heure à laquelle le test tourne.</summary>
internal sealed class HorlogeFixe(DateTimeOffset maintenant) : IClock
{
    public DateTimeOffset UtcNow => maintenant;
}
