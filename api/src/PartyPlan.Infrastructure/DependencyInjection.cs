namespace PartyPlan.Infrastructure;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Infrastructure.Email;
using PartyPlan.Infrastructure.Identity;
using PartyPlan.Infrastructure.Media;
using PartyPlan.Infrastructure.Notifications;
using PartyPlan.Infrastructure.Options;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.Modules.Administration.Persistence;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.Modules.Expenses.Persistence;
using PartyPlan.Modules.Messages.Persistence;
using PartyPlan.Modules.Notifications.Persistence;
using PartyPlan.Modules.Polls.Persistence;
using PartyPlan.Modules.Settlements.Persistence;
using PartyPlan.Modules.Shopping.Persistence;
using PartyPlan.Modules.Tasks.Persistence;
using PartyPlan.Modules.Users.Persistence;
using PartyPlan.SharedKernel.Abstractions;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<IIdGenerator, UuidV7Generator>();

        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, CurrentUser>();

        // Le périmètre est une instance unique par requête : le middleware le calcule,
        // le DbContext le lit.
        services.AddScoped<EventScope>();
        services.AddScoped<IEventScope>(sp => sp.GetRequiredService<EventScope>());
        services.AddScoped<EventScopePrimer>();

        services.AddOptions<DatabaseOptions>()
            .Bind(configuration.GetSection(DatabaseOptions.SectionName))
            .ValidateOnStart();

        services.AddOptions<AdminSeedOptions>()
            .Bind(configuration.GetSection(AdminSeedOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        // --- Courriel et médias ---
        services.AddOptions<SmtpOptions>()
            .Bind(configuration.GetSection(SmtpOptions.SectionName))
            .ValidateOnStart();

        services.AddOptions<MediaOptions>()
            .Bind(configuration.GetSection(MediaOptions.SectionName))
            .ValidateOnStart();

        services.AddSingleton<PartyPlan.SharedKernel.Contracts.IEmailSender, SmtpEmailSender>();
        services.AddSingleton<PartyPlan.SharedKernel.Contracts.IAvatarStorage, AvatarStorage>();
        services.AddSingleton<PartyPlan.SharedKernel.Contracts.IEventImageStorage, EventImageStorage>();

        // Notifications poussées. L'émetteur de développement journalise au lieu
        // d'envoyer (NF-DEV-04) ; l'implémentation Firebase le remplacera au lot 1.11,
        // derrière le même contrat.
        services.AddOptions<PushOptions>()
            .Bind(configuration.GetSection(PushOptions.SectionName))
            .ValidateOnStart();

        services.AddSingleton<PartyPlan.SharedKernel.Contracts.IPushSender, ConsolePushSender>();

        // --- Connexions tierces ---
        // Sans identifiant client configuré, la vérification échoue proprement : le
        // développement se fait par mot de passe (NF-DEV-05).
        services.AddOptions<GoogleOptions>()
            .Bind(configuration.GetSection(GoogleOptions.SectionName))
            .ValidateOnStart();

        services.AddHttpClient(nameof(GoogleIdentityVerifier))
            .ConfigureHttpClient(client => client.Timeout = TimeSpan.FromSeconds(10));

        services.AddSingleton<PartyPlan.SharedKernel.Contracts.IExternalIdentityVerifier,
            GoogleIdentityVerifier>();


        var connectionString = configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException(
                "La chaîne de connexion « ConnectionStrings:Default » est absente. "
                + "Voir .env.example (RG-DEV-02).");

        services.AddDbContext<PartyPlanDbContext>(options =>
            options.UseNpgsql(connectionString, npgsql =>
                {
                    npgsql.MigrationsAssembly(typeof(PartyPlanDbContext).Assembly.FullName);
                    npgsql.EnableRetryOnFailure(3);
                })
                // Les avertissements de traduction côté client sont des erreurs : une
                // évaluation en mémoire contournerait silencieusement les filtres de
                // cloisonnement.
                .ConfigureWarnings(w => w.Throw(Microsoft.EntityFrameworkCore.Diagnostics
                    .RelationalEventId.MultipleCollectionIncludeWarning)));

        AddModuleContracts(services);

        services.Add(Microsoft.Extensions.DependencyInjection.ServiceDescriptor.Singleton<
            Microsoft.Extensions.Hosting.IHostedService,
            Persistence.DatabaseInitializer>());

        services.AddHealthChecks()
            .AddDbContextCheck<PartyPlanDbContext>("database", tags: ["ready"]);

        return services;
    }

    /// <summary>
    /// Chaque module ne reçoit que son propre contrat de persistance, tous servis par
    /// le même contexte. C'est ainsi que la frontière de l'ADR 0002 devient une
    /// contrainte de compilation et non une consigne.
    /// </summary>
    private static void AddModuleContracts(IServiceCollection services)
    {
        services.AddScoped<IUsersDbContext>(Resolve);
        services.AddScoped<IAdministrationDbContext>(Resolve);
        services.AddScoped<IEventsDbContext>(Resolve);
        services.AddScoped<IShoppingDbContext>(Resolve);
        services.AddScoped<IExpensesDbContext>(Resolve);
        services.AddScoped<ISettlementsDbContext>(Resolve);
        services.AddScoped<ITasksDbContext>(Resolve);
        services.AddScoped<IPollsDbContext>(Resolve);
        services.AddScoped<IMessagesDbContext>(Resolve);
        services.AddScoped<INotificationsDbContext>(Resolve);

        static PartyPlanDbContext Resolve(IServiceProvider sp) => sp.GetRequiredService<PartyPlanDbContext>();
    }
}
