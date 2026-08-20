namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Expenses.Domain;
using PartyPlan.Modules.Settlements.Domain;
using Shouldly;
using Xunit;

/// <summary>
/// Jeu de test de référence du §6.5. Test bloquant : RG-TEST-01 interdit toute
/// livraison du domaine financier sans son passage.
/// <para>
/// Trois membres, trois dépenses partagées à parts égales entre tous.
/// </para>
/// </summary>
public sealed class JeuDeReferenceTests
{
    private static readonly Guid Maxence = Id(1);
    private static readonly Guid Lucas = Id(2);
    private static readonly Guid Emma = Id(3);

    private static readonly (Guid MemberId, int Share)[] Tous =
        [(Maxence, 1), (Lucas, 1), (Emma, 1)];

    /// <summary>Parts dues par membre, agrégées sur les trois dépenses.</summary>
    private static Dictionary<Guid, long> Du()
    {
        var du = new Dictionary<Guid, long> { [Maxence] = 0, [Lucas] = 0, [Emma] = 0 };

        foreach (var montant in new[] { 10_000, 5_000, 3_400 })
        {
            foreach (var part in Repartition.Repartir(montant, Tous))
            {
                du[part.MemberId] += part.Cents;
            }
        }

        return du;
    }

    [Fact]
    public void Les_parts_dues_totalisent_le_montant_des_depenses()
    {
        Du().Values.Sum().ShouldBe(18_400);
    }

    [Fact]
    public void Les_soldes_sont_ceux_annonces_par_le_cahier_des_charges()
    {
        var du = Du();

        var soldes = Soldes.Calculer(
            [
                new LigneDeCompte(Maxence, 10_000, du[Maxence]),
                new LigneDeCompte(Lucas, 5_000, du[Lucas]),
                new LigneDeCompte(Emma, 3_400, du[Emma]),
            ],
            []);

        var parMembre = soldes.ToDictionary(s => s.MemberId, s => s.Cents);

        // Répartition dépense par dépense, jamais sur le total : chaque dépense a son
        // propre payeur. Voir la correction du §6.5 du 20/08/2026.
        parMembre[Maxence].ShouldBe(3_865);
        parMembre[Lucas].ShouldBe(-1_133);
        parMembre[Emma].ShouldBe(-2_732);
    }

    [Fact]
    public void IV_02_la_somme_des_soldes_est_nulle()
    {
        var du = Du();

        var soldes = Soldes.Calculer(
            [
                new LigneDeCompte(Maxence, 10_000, du[Maxence]),
                new LigneDeCompte(Lucas, 5_000, du[Lucas]),
                new LigneDeCompte(Emma, 3_400, du[Emma]),
            ],
            []);

        Soldes.InvariantRespecte(soldes).ShouldBeTrue();
    }

    [Fact]
    public void Les_reglements_attendus_sont_produits_dans_l_ordre_attendu()
    {
        var du = Du();

        var soldes = Soldes.Calculer(
            [
                new LigneDeCompte(Maxence, 10_000, du[Maxence]),
                new LigneDeCompte(Lucas, 5_000, du[Lucas]),
                new LigneDeCompte(Emma, 3_400, du[Emma]),
            ],
            []);

        var reglements = Soldes.Simplifier(soldes);

        // Deux transactions au lieu des six d'un règlement bilatéral naïf, et dans cet
        // ordre exact : la dette la plus forte d'abord (§6.4, RG-CALC-01).
        reglements.Count.ShouldBe(2);
        reglements[0].ShouldBe(new Reglement(Emma, Maxence, 2_732));
        reglements[1].ShouldBe(new Reglement(Lucas, Maxence, 1_133));
        reglements.Sum(r => r.Cents).ShouldBe(3_865);
    }

    private static Guid Id(int rang) => new($"00000000-0000-0000-0000-{rang:D12}");
}
