namespace PartyPlan.UnitTests;

using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Catégories du fil d'activité (RG-FIL-01).
/// <para>
/// Une catégorie déclarée mais jamais écrite se relit comme un oubli d'implémentation,
/// et une catégorie manquante troue une trace qui prétend faire preuve. Ces tests
/// tiennent la liste au niveau de la règle.
/// </para>
/// </summary>
public sealed class ActivityKindsTests
{
    [Fact]
    public void All_couvre_les_treize_categories_de_RG_FIL_01()
    {
        ActivityKinds.All.Count.ShouldBe(13);
    }

    [Fact]
    public void All_ne_contient_aucun_doublon()
    {
        ActivityKinds.All.Distinct().Count().ShouldBe(ActivityKinds.All.Count);
    }

    [Fact]
    public void Le_planning_abandonne_ne_laisse_aucune_categorie()
    {
        // Le lot 1.9 a été abandonné le 21/08/2026. Le §9 a perdu schedule.changed à
        // cette occasion ; la catégorie du fil lui avait survécu.
        ActivityKinds.All.ShouldNotContain("event.schedule_changed");
    }

    [Fact]
    public void Chaque_action_defaisable_a_sa_categorie_d_annulation()
    {
        // Le trou que l'amendement du 26/08/2026 comble : un fil qui consigne
        // l'attribution mais pas la libération trompe là où il prétend faire preuve.
        ActivityKinds.All.ShouldContain(ActivityKinds.ItemUnclaimed);
        ActivityKinds.All.ShouldContain(ActivityKinds.ExpenseDeleted);
        ActivityKinds.All.ShouldContain(ActivityKinds.SettlementCancelled);
    }
}
