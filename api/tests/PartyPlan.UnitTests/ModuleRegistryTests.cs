namespace PartyPlan.UnitTests;

using PartyPlan.Infrastructure;
using PartyPlan.SharedKernel.Modules;
using Shouldly;
using Xunit;

public sealed class ModuleRegistryTests
{
    [Fact]
    public void Les_onze_modules_sont_decouverts()
    {
        var modules = ModuleRegistry.Discover([.. ModuleAssemblies.All]);

        modules.Count.ShouldBe(11);
        modules.Select(m => m.Name).ShouldContain("Events");
        modules.Select(m => m.Name).ShouldContain("Administration");
    }

    [Fact]
    public void L_ordre_de_decouverte_est_deterministe()
    {
        var premier = ModuleRegistry.Discover([.. ModuleAssemblies.All]).Select(m => m.Name).ToList();
        var second = ModuleRegistry.Discover([.. ModuleAssemblies.All]).Select(m => m.Name).ToList();

        // Deux démarrages doivent produire exactement la même composition.
        second.ShouldBe(premier);
        premier.ShouldBe([.. premier.OrderBy(n => n, StringComparer.Ordinal)]);
    }
}
