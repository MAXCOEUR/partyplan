namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Application;
using PartyPlan.SharedKernel.Primitives;
using Shouldly;
using Xunit;

/// <summary>
/// Décisions de quota de la formule gratuite (RG-PRM-01, ADR 0008).
/// <para>
/// Les frontières exactes sont testées parce qu'un quota mal borné ouvre ou ferme le
/// produit à tort : à 2 événements possédés on doit pouvoir créer, à 3 non, et un abonné
/// ne rencontre jamais la borne. Les décisions étant pures, aucune base n'est nécessaire.
/// </para>
/// </summary>
public sealed class QuotaEvenementsTests
{
    [Theory]
    [InlineData(0, true)]
    [InlineData(1, true)]
    [InlineData(2, true)]
    [InlineData(3, false)]
    [InlineData(4, false)]
    public void La_creation_est_bornee_a_trois_evenements_possedes(int possedes, bool attendu)
    {
        QuotaEvenements.CreationAutorisee(possedes, abonne: false).ShouldBe(attendu);
    }

    [Theory]
    [InlineData(3)]
    [InlineData(10)]
    [InlineData(100)]
    public void Un_abonne_ne_rencontre_jamais_la_borne_de_creation(int possedes)
    {
        QuotaEvenements.CreationAutorisee(possedes, abonne: true).ShouldBeTrue();
    }

    [Theory]
    [InlineData(0, true)]
    [InlineData(18, true)]
    [InlineData(19, true)]
    [InlineData(20, false)]
    [InlineData(21, false)]
    public void L_adhesion_est_bornee_a_vingt_membres_actifs(int membres, bool attendu)
    {
        QuotaEvenements.AdhesionAutorisee(membres, proprietaireAbonne: false).ShouldBe(attendu);
    }

    [Theory]
    [InlineData(20)]
    [InlineData(50)]
    public void Le_plafond_de_membres_est_leve_par_la_formule_du_proprietaire(int membres)
    {
        // EF-PRM-03 : la formule du propriétaire bénéficie à tous les membres. C'est la
        // sienne qui compte, jamais celle de l'arrivant.
        QuotaEvenements.AdhesionAutorisee(membres, proprietaireAbonne: true).ShouldBeTrue();
    }

    [Fact]
    public void Les_quotas_annonces_sont_ceux_du_cahier_des_charges()
    {
        QuotaEvenements.EvenementsMaximum.ShouldBe(3);
        QuotaEvenements.MembresMaximum.ShouldBe(20);
    }

    [Fact]
    public void Les_deux_refus_sont_des_interdictions_et_nomment_leur_sortie()
    {
        QuotaEvenements.QuotaAtteint.Code.ShouldBe("plan.event_quota_reached");
        QuotaEvenements.QuotaAtteint.Kind.ShouldBe(ErrorKind.Forbidden);
        QuotaEvenements.QuotaAtteint.Message.ShouldContain("3");

        QuotaEvenements.PlafondMembresAtteint.Code.ShouldBe("plan.member_limit_reached");
        QuotaEvenements.PlafondMembresAtteint.Kind.ShouldBe(ErrorKind.Forbidden);
        QuotaEvenements.PlafondMembresAtteint.Message.ShouldContain("20");
    }
}
