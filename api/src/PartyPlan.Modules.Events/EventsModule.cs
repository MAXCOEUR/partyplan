namespace PartyPlan.Modules.Events;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Events.Application;
using PartyPlan.Modules.Events.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

public sealed class EventsModule : IModule
{
    public string Name => "Events";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<EventService>();
        services.AddScoped<JoinService>();
        services.AddScoped<AttendanceService>();
        services.AddScoped<ActivityService>();

        // Contrat public consommé par l'administration : des décomptes, jamais de
        // contenu (RG-ADM-01).
        services.AddScoped<EventStatistics>();
        services.AddScoped<IEventStatistics>(sp => sp.GetRequiredService<EventStatistics>());

        // Appartenance, consommée par Shopping, Expenses et Settlements : aucun de ces
        // modules n'accède à event_members.
        services.AddScoped<IEventMembership, EventMembership>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => EventsEndpoints.Map(routes);
}
