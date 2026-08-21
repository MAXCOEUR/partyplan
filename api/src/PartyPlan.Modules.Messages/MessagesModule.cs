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

        // Contrat consommé par le module Polls : c'est Messages qui possède le fil.
        services.AddScoped<PartyPlan.SharedKernel.Contracts.IPollAnnouncement>(
            fournisseur => fournisseur.GetRequiredService<MessageService>());
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => MessagesEndpoints.Map(routes);
}
