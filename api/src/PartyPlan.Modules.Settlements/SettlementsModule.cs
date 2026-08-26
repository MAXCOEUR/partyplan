namespace PartyPlan.Modules.Settlements;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Settlements.Application;
using PartyPlan.Modules.Settlements.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>Module « Settlements » (ADR 0002).</summary>
public sealed class SettlementsModule : IModule
{
    public string Name => "Settlements";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<SettlementService>();

        // EF-NOT-06 : le montant dû vient du calcul qui fait foi.
        services.AddScoped<IPlanificateurRappels, RappelsDeDette>();

        // Contrat public consommé par Events pour RG-EVT-02 : un événement dont des
        // dettes restent en suspens ne se supprime pas sans confirmation renforcée.
        services.AddScoped<ISettlementStatus>(sp => sp.GetRequiredService<SettlementService>());
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => SettlementsEndpoints.Map(routes);
}
