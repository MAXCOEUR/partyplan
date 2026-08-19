namespace PartyPlan.SharedKernel.Modules;

using System.Reflection;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

/// <summary>
/// Découverte et branchement des modules. L'ordre d'enregistrement est déterminé par
/// le nom, afin que deux démarrages produisent exactement la même composition.
/// </summary>
public static class ModuleRegistry
{
    public static IReadOnlyList<IModule> Discover(params Assembly[] assemblies)
    {
        ArgumentNullException.ThrowIfNull(assemblies);

        return assemblies
            .SelectMany(a => a.GetTypes())
            .Where(t => typeof(IModule).IsAssignableFrom(t) && t is { IsAbstract: false, IsInterface: false })
            .Select(t => (IModule)Activator.CreateInstance(t)!)
            .OrderBy(m => m.Name, StringComparer.Ordinal)
            .ToList();
    }

    public static void AddModules(
        this IServiceCollection services,
        IConfiguration configuration,
        IReadOnlyList<IModule> modules)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(modules);

        foreach (var module in modules)
        {
            module.AddServices(services, configuration);
        }
    }

    public static void MapModules(this IEndpointRouteBuilder routes, IReadOnlyList<IModule> modules)
    {
        ArgumentNullException.ThrowIfNull(routes);
        ArgumentNullException.ThrowIfNull(modules);

        foreach (var module in modules)
        {
            module.MapEndpoints(routes);
        }
    }
}
