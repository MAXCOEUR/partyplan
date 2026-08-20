namespace PartyPlan.Modules.Expenses;

using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Modules.Expenses.Application;
using PartyPlan.Modules.Expenses.Endpoints;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Modules;

/// <summary>Module « Expenses » (ADR 0002).</summary>
public sealed class ExpensesModule : IModule
{
    public string Name => "Expenses";

    public void AddServices(IServiceCollection services, IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);

        services.AddScoped<ExpenseService>();

        // Deux contrats publics, servis par la même instance : le grand livre consommé
        // par Settlements, et la création depuis un achat consommée par Shopping. Aucun
        // de ces modules n'accède à la table des dépenses.
        services.AddScoped<IExpenseLedger>(sp => sp.GetRequiredService<ExpenseService>());
        services.AddScoped<IExpenseFromPurchase>(sp => sp.GetRequiredService<ExpenseService>());
    }

    public void MapEndpoints(IEndpointRouteBuilder routes) => ExpensesEndpoints.Map(routes);
}
