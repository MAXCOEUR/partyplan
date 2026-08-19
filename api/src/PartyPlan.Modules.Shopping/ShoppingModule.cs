namespace PartyPlan.Modules.Shopping;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Shopping » (ADR 0002). Les entités et le contrat de persistance sont en place ;
/// les services et endpoints arrivent avec le lot correspondant de docs/roadmap.md.
/// </summary>
public sealed class ShoppingModule : IModule
{
    public string Name => "Shopping";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        // Aucun service pour l'instant.
    }

    public void MapEndpoints(IEndpointRouteBuilder routes)
    {
        // Aucun endpoint pour l'instant.
    }
}
