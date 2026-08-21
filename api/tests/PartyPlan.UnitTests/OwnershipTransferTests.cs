namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Transfert de propriété d'un événement.
/// <para>
/// Rendu nécessaire par RG-ROLE-02 : le propriétaire ne peut pas quitter sans
/// transférer. Sans cette opération, la règle serait un cul-de-sac — un organisateur
/// resterait prisonnier de son propre événement.
/// </para>
/// </summary>
public sealed class OwnershipTransferTests
{
    private static EventMember Membre(
        EventMemberRole role,
        bool actif = true,
        bool avecCompte = true) => new()
        {
            Id = Guid.CreateVersion7(),
            EventId = Guid.CreateVersion7(),
            UserId = avecCompte ? Guid.CreateVersion7() : null,
            DisplayName = "Test",
            Role = role,
            RemovedAt = actif ? null : DateTimeOffset.UtcNow,
        };

    [Fact]
    public void Le_proprietaire_transfere_a_un_administrateur()
    {
        EventMember.CanTransferOwnership(
                Membre(EventMemberRole.Owner),
                Membre(EventMemberRole.Admin))
            .IsSuccess.ShouldBeTrue();
    }

    [Fact]
    public void Le_proprietaire_transfere_a_un_membre_ordinaire()
    {
        EventMember.CanTransferOwnership(
                Membre(EventMemberRole.Owner),
                Membre(EventMemberRole.Member))
            .IsSuccess.ShouldBeTrue();
    }

    [Theory]
    [InlineData(EventMemberRole.Admin)]
    [InlineData(EventMemberRole.Member)]
    public void Seul_le_proprietaire_transfere(EventMemberRole role)
    {
        var resultat = EventMember.CanTransferOwnership(
            Membre(role),
            Membre(EventMemberRole.Member));

        resultat.IsFailure.ShouldBeTrue();
        resultat.Error!.Code.ShouldBe("event.only_owner_transfers");
    }

    [Fact]
    public void Un_transfert_vers_soi_meme_est_refuse()
    {
        var proprietaire = Membre(EventMemberRole.Owner);

        // Sans ce refus, l'opération réussirait en ne changeant rien, et l'utilisateur
        // croirait avoir transféré.
        EventMember.CanTransferOwnership(proprietaire, proprietaire)
            .Error!.Code.ShouldBe("event.transfer_to_self");
    }

    [Fact]
    public void Un_transfert_vers_un_membre_exclu_est_refuse()
    {
        var resultat = EventMember.CanTransferOwnership(
            Membre(EventMemberRole.Owner),
            Membre(EventMemberRole.Member, actif: false));

        resultat.Error!.Code.ShouldBe("event.transfer_to_inactive");
    }

    [Fact]
    public void Un_transfert_vers_une_ligne_historique_sans_compte_est_refuse()
    {
        var resultat = EventMember.CanTransferOwnership(
            Membre(EventMemberRole.Owner),
            Membre(EventMemberRole.Member, avecCompte: false));

        // Une ligne historique sans compte ne peut pas représenter un appelant : le
        // transfert rendrait donc l'événement impossible à administrer.
        resultat.Error!.Code.ShouldBe("event.transfer_needs_account");
    }
}
