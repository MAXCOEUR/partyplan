namespace PartyPlan.Modules.Shopping;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.SharedKernel.Contracts;
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

        // EF-NOT-04 : les articles sans preneur se comptent ici, pas ailleurs.
        services.AddScoped<IPlanificateurRappels, RappelsDArticles>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => ShoppingEndpoints.Map(routes);
}
