namespace PartyPlan.Modules.Events;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Events.Application;
using PartyPlan.Modules.Events.Endpoints;
using PartyPlan.SharedKernel.Modules;

public sealed class EventsModule : IModule
{
    public string Name => "Events";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<EventReader>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => EventsEndpoints.Map(routes);
}
