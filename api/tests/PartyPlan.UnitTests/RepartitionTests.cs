namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Expenses.Domain;
using Shouldly;
using Xunit;

/// <summary>
/// Répartition d'une dépense au centime (§6.2) et invariant IV-01.
/// <para>
/// C'est la règle la plus sensible du produit : une erreur d'un centime ici se propage
/// à tous les soldes et à tous les règlements.
/// </para>
/// </summary>
public sealed class RepartitionTests
{
    [Fact]
    public void IV_01_la_somme_des_parts_egale_exactement_le_montant()
    {
        var parts = Repartition.Repartir(18_400, [(Id(1), 1), (Id(2), 1), (Id(3), 1)]);

        parts.Sum(p => p.Cents).ShouldBe(18_400);
    }

    [Fact]
    public void Le_reliquat_va_aux_plus_grands_restes()
    {
        // 10 000 / 3 = 3 333,33 : un centime à distribuer, restes égaux, donc à
        // l'identifiant le plus petit.
        var parts = Repartition.Repartir(10_000, [(Id(1), 1), (Id(2), 1), (Id(3), 1)]);

        parts.Select(p => p.Cents).ShouldBe([3_334, 3_333, 3_333]);
    }

    [Fact]
    public void Deux_centimes_de_reliquat_vont_aux_deux_premiers()
    {
        // 5 000 / 3 = 1 666,67 : deux centimes à distribuer.
        var parts = Repartition.Repartir(5_000, [(Id(1), 1), (Id(2), 1), (Id(3), 1)]);

        parts.Select(p => p.Cents).ShouldBe([1_667, 1_667, 1_666]);
    }

    [Fact]
    public void Les_parts_personnalisees_ponderent_la_repartition()
    {
        // Une part double : 100 / 4 quarts, soit 50 pour le premier et 25 pour chacun.
        var parts = Repartition.Repartir(100, [(Id(1), 2), (Id(2), 1), (Id(3), 1)]);

        parts.Select(p => p.Cents).ShouldBe([50, 25, 25]);
    }

    [Fact]
    public void Le_plus_grand_reste_prime_sur_l_identifiant()
    {
        // 10 / 3 avec parts 2/1/1 : théoriques 5,0 · 2,5 · 2,5. Le premier n'a aucun
        // reste, les deux autres en ont un : c'est à eux que va le centime, et non au
        // plus petit identifiant.
        var parts = Repartition.Repartir(10, [(Id(1), 2), (Id(2), 1), (Id(3), 1)]);

        parts.Select(p => p.Cents).ShouldBe([5, 3, 2]);
    }

    [Fact]
    public void Un_seul_participant_recoit_tout()
    {
        Repartition.Repartir(1_234, [(Id(1), 1)]).Single().Cents.ShouldBe(1_234);
    }

    [Fact]
    public void Le_resultat_est_reproductible_quel_que_soit_l_ordre_d_entree()
    {
        var croissant = Repartition.Repartir(
            10_000,
            [(Id(1), 1), (Id(2), 1), (Id(3), 1)]);

        var decroissant = Repartition.Repartir(
            10_000,
            [(Id(3), 1), (Id(2), 1), (Id(1), 1)]);

        // RG-RMB-01 : le résultat ne dépend pas de l'ordre dans lequel l'assiette est
        // fournie, sans quoi deux appels identiques donneraient deux répartitions.
        decroissant.OrderBy(p => p.MemberId).Select(p => p.Cents)
            .ShouldBe(croissant.OrderBy(p => p.MemberId).Select(p => p.Cents));
    }

    [Theory]
    [InlineData(1)]
    [InlineData(7)]
    [InlineData(99)]
    [InlineData(9_999_999)]
    public void IV_01_tient_sur_des_montants_et_des_assiettes_varies(int montant)
    {
        foreach (var n in new[] { 1, 2, 3, 5, 7, 11 })
        {
            var assiette = Enumerable.Range(1, n).Select(i => (Id(i), 1)).ToList();

            Repartition.Repartir(montant, assiette).Sum(p => p.Cents).ShouldBe(montant);
        }
    }

    [Fact]
    public void Un_montant_nul_ou_negatif_est_refuse()
    {
        Should.Throw<ArgumentOutOfRangeException>(
            () => Repartition.Repartir(0, [(Id(1), 1)]));
        Should.Throw<ArgumentOutOfRangeException>(
            () => Repartition.Repartir(-1, [(Id(1), 1)]));
    }

    [Fact]
    public void Une_assiette_vide_est_refusee()
    {
        Should.Throw<ArgumentException>(() => Repartition.Repartir(100, []));
    }

    [Fact]
    public void Une_part_nulle_ou_negative_est_refusee()
    {
        Should.Throw<ArgumentOutOfRangeException>(
            () => Repartition.Repartir(100, [(Id(1), 0)]));
        Should.Throw<ArgumentOutOfRangeException>(
            () => Repartition.Repartir(100, [(Id(1), -3)]));
    }

    /// <summary>Identifiant ordonnable et lisible dans un message d'échec.</summary>
    private static Guid Id(int rang) => new($"00000000-0000-0000-0000-{rang:D12}");
}
