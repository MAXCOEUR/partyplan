namespace PartyPlan.UnitTests;

using PartyPlan.Modules.Events.Domain;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Règles de rôle au sein d'un événement (RG-ROLE-01 à RG-ROLE-03).
/// <para>
/// Ces règles évitent qu'un administrateur promu prenne le contrôle d'un événement qui
/// n'est pas le sien, et qu'un départ laisse l'événement sans propriétaire.
/// </para>
/// </summary>
public sealed class EventRolesTests
{
    private static EventMember Membre(EventMemberRole role, bool actif = true) => new()
    {
        Id = Guid.CreateVersion7(),
        EventId = Guid.CreateVersion7(),
        DisplayName = "Test",
        Role = role,
        RemovedAt = actif ? null : DateTimeOffset.UtcNow,
    };

    [Theory]
    [InlineData(EventMemberRole.Owner, true)]
    [InlineData(EventMemberRole.Admin, true)]
    [InlineData(EventMemberRole.Member, false)]
    public void Seuls_le_proprietaire_et_les_administrateurs_modifient_l_evenement(
        EventMemberRole role,
        bool autorise)
    {
        Membre(role).CanManageEvent.ShouldBe(autorise);
    }

    [Theory]
    [InlineData(EventMemberRole.Owner, true)]
    [InlineData(EventMemberRole.Admin, false)]
    [InlineData(EventMemberRole.Member, false)]
    public void Seul_le_proprietaire_supprime_l_evenement(EventMemberRole role, bool autorise)
    {
        // RG-ROLE-01 : un administrateur ne peut pas supprimer l'événement.
        Membre(role).CanDeleteEvent.ShouldBe(autorise);
    }

    [Fact]
    public void Un_membre_exclu_perd_tout_droit()
    {
        var exclu = Membre(EventMemberRole.Admin, actif: false);

        exclu.CanManageEvent.ShouldBeFalse();
        exclu.IsActive.ShouldBeFalse();
    }

    [Fact]
    public void Un_administrateur_ne_peut_pas_exclure_le_proprietaire()
    {
        var administrateur = Membre(EventMemberRole.Admin);
        var proprietaire = Membre(EventMemberRole.Owner);

        // RG-ROLE-01
        EventMember.CanRemove(administrateur, proprietaire).IsFailure.ShouldBeTrue();
        EventMember.CanRemove(administrateur, proprietaire).Error!.Code
            .ShouldBe("event.cannot_remove_owner");
    }

    [Fact]
    public void Le_proprietaire_peut_exclure_un_administrateur()
    {
        EventMember.CanRemove(Membre(EventMemberRole.Owner), Membre(EventMemberRole.Admin))
            .IsSuccess.ShouldBeTrue();
    }

    [Fact]
    public void Un_membre_ordinaire_n_exclut_personne()
    {
        EventMember.CanRemove(Membre(EventMemberRole.Member), Membre(EventMemberRole.Member))
            .IsFailure.ShouldBeTrue();
    }

    [Fact]
    public void Personne_ne_s_exclut_soi_meme_par_l_exclusion()
    {
        var proprietaire = Membre(EventMemberRole.Owner);

        // Quitter un événement est une autre opération : elle vérifie le transfert de
        // propriété (RG-ROLE-02).
        EventMember.CanRemove(proprietaire, proprietaire).Error!.Code
            .ShouldBe("event.cannot_remove_self");
    }

    [Fact]
    public void Le_proprietaire_ne_peut_pas_quitter_sans_transferer()
    {
        var resultat = EventMember.CanLeave(Membre(EventMemberRole.Owner));

        // RG-ROLE-02 : sans quoi l'événement se retrouverait sans propriétaire, donc
        // impossible à supprimer ou à administrer.
        resultat.IsFailure.ShouldBeTrue();
        resultat.Error!.Code.ShouldBe("event.owner_must_transfer");
    }

    [Theory]
    [InlineData(EventMemberRole.Admin)]
    [InlineData(EventMemberRole.Member)]
    public void Les_autres_membres_peuvent_quitter(EventMemberRole role)
    {
        EventMember.CanLeave(Membre(role)).IsSuccess.ShouldBeTrue();
    }
}

/// <summary>Décomptes de présence (RG-PRES-02, RG-PRES-03, EF-PRES-05, EF-PRES-06).</summary>
public sealed class AttendanceCountTests
{
    private static EventMember Avec(EventMemberStatus statut, short accompagnants = 0) => new()
    {
        Id = Guid.CreateVersion7(),
        EventId = Guid.CreateVersion7(),
        DisplayName = "Test",
        Status = statut,
        ExtraGuests = accompagnants,
    };

    [Fact]
    public void Le_decompte_des_presents_inclut_les_retards_et_departs_anticipes()
    {
        var membres = new[]
        {
            Avec(EventMemberStatus.Going),
            Avec(EventMemberStatus.Late),
            Avec(EventMemberStatus.EarlyLeave),
            Avec(EventMemberStatus.Maybe),
            Avec(EventMemberStatus.NotGoing),
            Avec(EventMemberStatus.Unknown),
        };

        // RG-PRES-02 et RG-PRES-03.
        AttendanceCount.From(membres).Present.ShouldBe(3);
        AttendanceCount.From(membres).Maybe.ShouldBe(1);
        AttendanceCount.From(membres).Invited.ShouldBe(6);
    }

    [Fact]
    public void Les_accompagnants_comptent_dans_le_total_des_tetes()
    {
        var membres = new[]
        {
            Avec(EventMemberStatus.Going, accompagnants: 2),
            Avec(EventMemberStatus.Going),
        };

        var decompte = AttendanceCount.From(membres);

        // EF-PRES-06 : l'organisateur achète pour des têtes, pas pour des comptes.
        decompte.Present.ShouldBe(2);
        decompte.Heads.ShouldBe(4);
    }

    [Fact]
    public void Les_accompagnants_d_un_absent_ne_comptent_pas()
    {
        var decompte = AttendanceCount.From([Avec(EventMemberStatus.NotGoing, accompagnants: 3)]);

        decompte.Heads.ShouldBe(0);
    }

    [Fact]
    public void Un_evenement_sans_membre_ne_fait_pas_echouer_le_decompte()
    {
        var decompte = AttendanceCount.From([]);

        decompte.Present.ShouldBe(0);
        decompte.Invited.ShouldBe(0);
        decompte.Heads.ShouldBe(0);
    }
}
