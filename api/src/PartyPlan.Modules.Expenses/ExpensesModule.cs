namespace PartyPlan.Modules.Expenses;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Expenses » (ADR 0002). Les entités et le contrat de persistance sont en place ;
/// les services et endpoints arrivent avec le lot correspondant de docs/roadmap.md.
/// </summary>
public sealed class ExpensesModule : IModule
{
    public string Name => "Expenses";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        // Aucun service pour l'instant.
    }

    public void MapEndpoints(IEndpointRouteBuilder routes)
    {
        // Aucun endpoint pour l'instant.
    }
}
