namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Notifications.Application;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Ce qu'une notification enregistrée devient une fois poussée.
/// <para>
/// La correspondance est vérifiée ici plutôt que dans la passe d'envoi : celle-ci ne
/// livre rien d'observable en test, l'émetteur retombant sur la console faute de clé.
/// </para>
/// </summary>
public sealed class MessagePousseTests
{
    private static readonly Guid Soiree = Guid.Parse("11111111-1111-1111-1111-111111111111");

    [Fact]
    public void La_categorie_et_la_soiree_viennent_de_la_notification()
    {
        var message = MessagePousse.Depuis(
            new Notification
            {
                EventId = Soiree,
                Category = NotificationCategories.DiscussionMessage,
                Title = "Lucas",
                Body = "On arrive.",
                DeepLink = "/events/x/discussion",
            },
            "jeton");

        message.Category.ShouldBe("discussion.message");
        message.EventId.ShouldBe(Soiree.ToString());
        message.DeepLink.ShouldBe("/events/x/discussion");
    }

    [Fact]
    public void La_cle_de_groupe_prefixe_la_soiree_sans_la_remplacer()
    {
        // Les deux champs portent la même soirée pour deux usages : l'empilement sur
        // l'appareil veut un espace de noms, la comparaison côté application veut
        // l'identifiant nu. Confondre les deux ferait échouer l'une ou l'autre.
        var message = MessagePousse.Depuis(
            new Notification { EventId = Soiree, Category = NotificationCategories.Activity },
            "jeton");

        message.GroupKey.ShouldBe($"event:{Soiree}");
        message.EventId.ShouldBe(Soiree.ToString());
    }

    [Fact]
    public void Une_notification_hors_soiree_ne_porte_ni_groupe_ni_evenement()
    {
        var message = MessagePousse.Depuis(
            new Notification { Category = NotificationCategories.BalanceDue, Title = "Solde" },
            "jeton");

        message.GroupKey.ShouldBeNull();
        message.EventId.ShouldBeNull();
        message.Category.ShouldBe("balance.due");
    }
}
