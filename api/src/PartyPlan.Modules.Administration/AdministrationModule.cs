namespace PartyPlan.Modules.Administration;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Administration » (ADR 0002). Les entités et le contrat de persistance sont en place ;
/// les services et endpoints arrivent avec le lot correspondant de docs/roadmap.md.
/// </summary>
public sealed class AdministrationModule : IModule
{
    public string Name => "Administration";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        // Aucun service pour l'instant.
    }

    public void MapEndpoints(IEndpointRouteBuilder routes)
    {
        // Aucun endpoint pour l'instant.
    }
}
