namespace PartyPlan.Modules.Users;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Users.Application;
using PartyPlan.Modules.Users.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Users » : propriétaire du compte, des sessions et des jetons à usage unique.
/// <para>
/// Il porte aussi les endpoints d'authentification. Le compte et l'authentification sont
/// le même agrégat : les séparer aurait imposé un contrat inter-modules à chaque
/// connexion, pour aucun bénéfice. Le module Auth conserve les mécanismes purs —
/// hachage, politique, émission de jetons.
/// </para>
/// </summary>
public sealed class UsersModule : IModule
{
    public string Name => "Users";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<AuthenticationService>();
        services.AddScoped<AccountService>();
        services.AddScoped<IPasswordResetTrigger>(sp => sp.GetRequiredService<AccountService>());
        services.AddScoped<AccountDeletionService>();

        // Contrat public consommé par l'administration (ADR 0002).
        services.AddScoped<UserDirectory>();
        services.AddScoped<IUserDirectory>(sp => sp.GetRequiredService<UserDirectory>());

        services.AddOptions<AdminSeedSettings>()
            .Bind(configuration!.GetSection(AdminSeedSettings.SectionName))
            .ValidateOnStart();

        services.AddScoped<AdminSeeder>();
        services.AddScoped<TotpService>();

        services.AddOptions<TotpIssuerOptions>()
            .Bind(configuration.GetSection(TotpIssuerOptions.SectionName))
            .ValidateOnStart();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes)
    {
        AuthEndpoints.Map(routes);
        MeEndpoints.Map(routes);
    }
}
