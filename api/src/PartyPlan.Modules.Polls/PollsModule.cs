namespace PartyPlan.Modules.Polls;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Polls.Application;
using PartyPlan.Modules.Polls.Endpoints;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Polls » (ADR 0002). Les entités et le contrat de persistance sont en place ;
/// les services et endpoints arrivent avec le lot correspondant de docs/roadmap.md.
/// </summary>
public sealed class PollsModule : IModule
{
    public string Name => "Polls";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<PollService>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => PollsEndpoints.Map(routes);
}
