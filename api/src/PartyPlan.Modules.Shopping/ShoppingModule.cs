namespace PartyPlan.Modules.Shopping;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Shopping.Application;
using PartyPlan.Modules.Shopping.Endpoints;
using PartyPlan.SharedKernel.Modules;

/// <summary>Module « Shopping » (ADR 0002).</summary>
public sealed class ShoppingModule : IModule
{
    public string Name => "Shopping";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<ShoppingService>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => ShoppingEndpoints.Map(routes);
}
