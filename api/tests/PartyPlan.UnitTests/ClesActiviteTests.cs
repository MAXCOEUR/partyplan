namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Shopping.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Clé de déduplication des notifications d'activité (<c>RG-NOT-02</c>, <c>EF-NOT-10</c>).
/// <para>
/// L'article et la nature du geste doivent porter la clé, pas l'instant : deux prises en
/// charge simultanées, par deux personnes différentes, destinées au même tiers, ne
/// doivent jamais s'effacer l'une l'autre parce qu'elles sont arrivées à la même
/// milliseconde.
/// </para>
/// </summary>
public sealed class ClesActiviteTests
{
    private static readonly Guid Evenement = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private static readonly Guid Destinataire = Guid.Parse("22222222-2222-2222-2222-222222222222");
    private static readonly Guid ArticleA = Guid.Parse("33333333-3333-3333-3333-333333333333");
    private static readonly Guid ArticleB = Guid.Parse("44444444-4444-4444-4444-444444444444");

    [Fact]
    public void Deux_articles_differents_produisent_des_cles_differentes()
    {
        var premiere = ClesActivite.Deduplication(
            Evenement, Destinataire, ArticleA, ClesActivite.PriseEnCharge);
        var seconde = ClesActivite.Deduplication(
            Evenement, Destinataire, ArticleB, ClesActivite.PriseEnCharge);

        premiere.ShouldNotBe(seconde);
    }

    [Fact]
    public void La_prise_en_charge_et_l_achat_du_meme_article_produisent_des_cles_differentes()
    {
        var priseEnCharge = ClesActivite.Deduplication(
            Evenement, Destinataire, ArticleA, ClesActivite.PriseEnCharge);
        var achat = ClesActivite.Deduplication(
            Evenement, Destinataire, ArticleA, ClesActivite.Achat);

        priseEnCharge.ShouldNotBe(achat);
    }

    [Fact]
    public void La_cle_ne_depend_d_aucun_instant_et_est_stable()
    {
        // Aucun horodatage en entrée : deux appels avec les mêmes paramètres, même
        // espacés dans le temps, produisent toujours la même clé.
        var premier = ClesActivite.Deduplication(
            Evenement, Destinataire, ArticleA, ClesActivite.PriseEnCharge);
        var second = ClesActivite.Deduplication(
            Evenement, Destinataire, ArticleA, ClesActivite.PriseEnCharge);

        premier.ShouldBe(second);
    }

    [Fact]
    public void La_cle_porte_l_evenement_le_destinataire_l_article_et_le_geste()
    {
        ClesActivite.Deduplication(Evenement, Destinataire, ArticleA, ClesActivite.PriseEnCharge)
            .ShouldBe($"{Evenement}:activity:{Destinataire}:{ArticleA}:claim");
    }
}
