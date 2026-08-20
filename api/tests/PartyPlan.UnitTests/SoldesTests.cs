namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Expenses.Domain;
using PartyPlan.Modules.Settlements.Domain;
using Shouldly;
using Xunit;

/// <summary>Soldes (§6.3) et simplification des règlements (§6.4).</summary>
public sealed class SoldesTests
{
    [Fact]
    public void Le_solde_vaut_avance_moins_du()
    {
        var soldes = Soldes.Calculer(
            [new LigneDeCompte(Id(1), 10_000, 6_000), new LigneDeCompte(Id(2), 0, 4_000)],
            []);

        soldes.Single(s => s.MemberId == Id(1)).Cents.ShouldBe(4_000);
        soldes.Single(s => s.MemberId == Id(2)).Cents.ShouldBe(-4_000);
    }

    [Fact]
    public void RG_RMB_03_un_reglement_effectue_entre_dans_le_calcul_suivant()
    {
        var comptes = new[]
        {
            new LigneDeCompte(Id(1), 10_000, 5_000),
            new LigneDeCompte(Id(2), 0, 5_000),
        };

        var avant = Soldes.Calculer(comptes, []);
        avant.Single(s => s.MemberId == Id(2)).Cents.ShouldBe(-5_000);

        // Sans cette prise en compte, une dette remboursée réapparaîtrait indéfiniment.
        var apres = Soldes.Calculer(
            comptes,
            [new ReglementEffectue(Id(2), Id(1), 5_000)]);

        apres.ShouldAllBe(s => s.Cents == 0);
    }

    [Fact]
    public void Un_reglement_vers_un_membre_inconnu_n_interrompt_pas_le_calcul()
    {
        // Un membre exclu conserve ses lignes financières (RG-ROLE-03) mais peut ne plus
        // figurer dans l'assiette courante.
        var soldes = Soldes.Calculer(
            [new LigneDeCompte(Id(1), 1_000, 1_000)],
            [new ReglementEffectue(Id(1), Id(9), 300)]);

        soldes.Single().Cents.ShouldBe(300);
    }

    [Fact]
    public void IV_02_est_signale_lorsqu_il_est_rompu()
    {
        Soldes.InvariantRespecte([new Solde(Id(1), 100), new Solde(Id(2), -100)])
            .ShouldBeTrue();
        Soldes.InvariantRespecte([new Solde(Id(1), 100), new Solde(Id(2), -99)])
            .ShouldBeFalse();
    }

    [Fact]
    public void L_appariement_produit_au_plus_n_moins_1_transferts()
    {
        var soldes = new[]
        {
            new Solde(Id(1), 3_000),
            new Solde(Id(2), 1_000),
            new Solde(Id(3), -2_500),
            new Solde(Id(4), -1_500),
        };

        var reglements = Soldes.Simplifier(soldes);

        reglements.Count.ShouldBeLessThanOrEqualTo(3);
        reglements.Sum(r => r.Cents).ShouldBe(4_000);
    }

    [Fact]
    public void RG_CALC_01_la_dette_la_plus_forte_est_apparee_en_premier()
    {
        var reglements = Soldes.Simplifier(
        [
            new Solde(Id(1), 5_000),
            new Solde(Id(2), -1_000),
            new Solde(Id(3), -4_000),
        ]);

        // L'ordre d'émission est celui qu'affiche l'interface : le trier ensuite rendrait
        // la liste incompréhensible d'un rafraîchissement à l'autre.
        reglements[0].ShouldBe(new Reglement(Id(3), Id(1), 4_000));
        reglements[1].ShouldBe(new Reglement(Id(2), Id(1), 1_000));
    }

    [Fact]
    public void Les_soldes_nuls_ne_produisent_aucun_transfert()
    {
        Soldes.Simplifier([new Solde(Id(1), 0), new Solde(Id(2), 0)]).ShouldBeEmpty();
        Soldes.Simplifier([]).ShouldBeEmpty();
    }

    [Fact]
    public void RG_RMB_01_le_resultat_est_reproductible_a_l_identique()
    {
        var soldes = new[]
        {
            new Solde(Id(3), 2_000),
            new Solde(Id(1), 2_000),
            new Solde(Id(2), -4_000),
        };

        var premier = Soldes.Simplifier(soldes);
        var second = Soldes.Simplifier([.. soldes.Reverse()]);

        // Deux créditeurs à solde égal : c'est l'identifiant croissant qui tranche, et
        // l'ordre d'entrée ne doit rien changer.
        second.ShouldBe(premier);
        premier[0].ShouldBe(new Reglement(Id(2), Id(1), 2_000));
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    [InlineData(5)]
    public void RG_TEST_02_IV_02_tient_sur_des_donnees_generees(int graine)
    {
        var alea = new Random(graine);

        for (var essai = 0; essai < 200; essai++)
        {
            var membres = Enumerable.Range(1, alea.Next(2, 9)).Select(Id).ToList();
            var avance = membres.ToDictionary(m => m, _ => 0L);
            var du = membres.ToDictionary(m => m, _ => 0L);

            foreach (var _ in Enumerable.Range(0, alea.Next(1, 20)))
            {
                var montant = alea.Next(1, 500_000);
                var assiette = membres
                    .Where(_ => alea.Next(2) == 0)
                    .Select(m => (m, alea.Next(1, 4)))
                    .ToList();

                if (assiette.Count == 0)
                {
                    continue;
                }

                avance[membres[alea.Next(membres.Count)]] += montant;

                foreach (var part in Repartition.Repartir(montant, assiette))
                {
                    du[part.MemberId] += part.Cents;
                }
            }

            var soldes = Soldes.Calculer(
                [.. membres.Select(m => new LigneDeCompte(m, avance[m], du[m]))],
                []);

            Soldes.InvariantRespecte(soldes).ShouldBeTrue();

            // La simplification conserve l'invariant : la somme des transferts égale la
            // somme des créances.
            var reglements = Soldes.Simplifier(soldes);
            reglements.Sum(r => r.Cents)
                .ShouldBe(soldes.Where(s => s.Cents > 0).Sum(s => s.Cents));
            reglements.Count.ShouldBeLessThanOrEqualTo(
                Math.Max(0, soldes.Count(s => s.Cents != 0) - 1));
        }
    }

    private static Guid Id(int rang) => new($"00000000-0000-0000-0000-{rang:D12}");
}
