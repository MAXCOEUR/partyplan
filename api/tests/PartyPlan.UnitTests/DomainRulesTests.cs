namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Shopping.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>Règles de domaine déjà portées par les entités.</summary>
public sealed class DomainRulesTests
{
    [Fact]
    public void Une_fin_absente_vaut_douze_heures_apres_le_debut()
    {
        var start = new DateTimeOffset(2026, 8, 29, 20, 0, 0, TimeSpan.Zero);
        var soiree = new Event { StartsAt = start };

        // EF-EVT-02
        soiree.EffectiveEndsAt.ShouldBe(start.AddHours(12));
    }

    [Fact]
    public void Une_fin_renseignee_prime()
    {
        var start = new DateTimeOffset(2026, 8, 29, 20, 0, 0, TimeSpan.Zero);
        var soiree = new Event { StartsAt = start, EndsAt = start.AddHours(4) };

        soiree.EffectiveEndsAt.ShouldBe(start.AddHours(4));
    }

    [Theory]
    [InlineData(EventMemberStatus.Going, true)]
    [InlineData(EventMemberStatus.Late, true)]
    [InlineData(EventMemberStatus.EarlyLeave, true)]
    [InlineData(EventMemberStatus.Maybe, false)]
    [InlineData(EventMemberStatus.NotGoing, false)]
    [InlineData(EventMemberStatus.Unknown, false)]
    public void Le_decompte_des_presents_suit_la_regle(EventMemberStatus status, bool expected)
    {
        // RG-PRES-02 : « arrive plus tard » et « part plus tôt » comptent comme présents.
        // RG-PRES-03 : « peut-être » non.
        new EventMember { Status = status }.CountsAsPresent.ShouldBe(expected);
    }

    [Fact]
    public void Le_statut_initial_n_est_jamais_present()
    {
        // RG-PRES-01
        new EventMember().Status.ShouldBe(EventMemberStatus.Unknown);
        new EventMember().CountsAsPresent.ShouldBeFalse();
    }

    [Theory]
    [InlineData(4, 2, 2)]
    [InlineData(4, 4, 0)]
    [InlineData(4, 6, 0)]
    [InlineData(4, null, 4)]
    public void Le_reliquat_d_un_article_ne_devient_jamais_negatif(
        int demandee, int? achetee, int attendu)
    {
        // RG-CRS-02. Paramètres entiers : xUnit ne convertit pas un littéral entier
        // vers un decimal nullable.
        var article = new ShoppingItem
        {
            Quantity = demandee,
            PurchasedQuantity = achetee,
        };

        article.RemainingQuantity.ShouldBe(attendu);
    }

    [Fact]
    public void Toute_categorie_est_declaree_dans_All()
    {
        // `All` sert l'écran des préférences : une catégorie absente devient invisible
        // et donc non désactivable, ce que EF-NOT-07 interdit.
        NotificationCategories.All.ShouldContain(NotificationCategories.DiscussionMessage);
        NotificationCategories.All.ShouldContain(NotificationCategories.DiscussionMention);
        NotificationCategories.All.ShouldContain(NotificationCategories.PollNew);
        NotificationCategories.All.ShouldContain(NotificationCategories.ExpenseNew);
        NotificationCategories.All.Length.ShouldBe(11);
    }
}
