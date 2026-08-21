namespace PartyPlan.Modules.Messages;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Messages.Application;
using PartyPlan.Modules.Messages.Endpoints;
using PartyPlan.SharedKernel.Modules;

/// <summary>Module « Messages » (ADR 0002) : discussion, réactions, épingles.</summary>
public sealed class MessagesModule : IModule
{
    public string Name => "Messages";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<MessageService>();
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => MessagesEndpoints.Map(routes);
}
