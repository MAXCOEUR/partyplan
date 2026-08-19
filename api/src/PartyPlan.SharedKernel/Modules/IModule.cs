namespace PartyPlan.SharedKernel.Modules;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

/// <summary>
/// Contrat d'un module métier (ADR 0002). L'hôte découvre les modules et les branche
/// sans les connaître individuellement : ajouter un module ne modifie pas l'hôte.
/// </summary>
public interface IModule
{
    /// <summary>Nom du module, utilisé pour le regroupement OpenAPI et les journaux.</summary>
    string Name { get; }

    /// <summary>Enregistre les services du module.</summary>
    void AddServices(IServiceCollection services, IConfiguration configuration);

    /// <summary>
    /// Déclare les endpoints du module sous le groupe versionné fourni par l'hôte.
    /// Un module ne choisit ni son préfixe de version ni sa politique d'authentification.
    /// </summary>
    void MapEndpoints(IEndpointRouteBuilder routes);
}
