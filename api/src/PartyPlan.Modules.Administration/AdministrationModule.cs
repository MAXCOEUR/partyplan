namespace PartyPlan.Modules.Administration;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Administration.Application;
using PartyPlan.Modules.Administration.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>
/// Module « Administration » : back-office des comptes et journal d'audit.
/// <para>
/// Il ne possède qu'une table, celle du journal. Les comptes appartiennent au module
/// Users, consulté par le contrat <see cref="IUserDirectory"/> : l'administration agit
/// sur des comptes, jamais sur le contenu d'un événement (RG-ADM-01).
/// </para>
/// </summary>
public sealed class AdministrationModule : IModule
{
    public string Name => "Administration";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<AuditLog>();
        services.AddScoped<IAuditLog>(sp => sp.GetRequiredService<AuditLog>());
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => AdminEndpoints.Map(routes);
}
