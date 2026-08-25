namespace PartyPlan.Modules.Notifications;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Notifications.Application;
using PartyPlan.Modules.Notifications.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Notifications » (ADR 0002). Le transport est en place ; les déclencheurs
/// métier arrivent avec le reste du lot 1.11 de docs/roadmap.md.
/// </summary>
public sealed class NotificationsModule : IModule
{
    public string Name => "Notifications";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<DeviceService>();

        // Contrat public consommé par l'émetteur de l'Infrastructure, qui ne doit pas
        // écrire dans push_devices lui-même (règle 6).
        services.AddScoped<IPushDeviceRegistry>(sp => sp.GetRequiredService<DeviceService>());
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => DeviceEndpoints.Map(routes);
}
