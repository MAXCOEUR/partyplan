namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Événements et invitations (EF-EVT-01 à EF-EVT-07, EF-INV-01 à EF-INV-06).
/// <para>
/// Le parcours « lien → prénom → présence » est le chemin le plus critique du produit
/// pour l'adoption : toute friction s'y paie en taux de réponse.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class EvenementsTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Un_utilisateur_cree_un_evenement_et_en_devient_proprietaire()
    {
        var organisateur = await CompteAsync();

        var reponse = await organisateur.PostAsJsonAsync("/v1/events", new
        {
            name = "Anniversaire de test",
            description = "Barbecue puis soirée.",
            startsAt = DateTimeOffset.UtcNow.AddDays(10),
            address = "Replonges",
        });

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var evenement = (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        evenement.GetProperty("name").GetString().ShouldBe("Anniversaire de test");

        // Le créateur est compté présent : il organise, il vient.
        evenement.GetProperty("memberCount").GetInt32().ShouldBe(1);
        evenement.GetProperty("presentCount").GetInt32().ShouldBe(1);
        evenement.GetProperty("joinEnabled").GetBoolean().ShouldBeTrue();

        var liste = await organisateur.GetFromJsonAsync<JsonDocument>("/v1/events");
        liste!.RootElement.EnumerateArray()
            .Single()
            .GetProperty("myRole").GetString().ShouldBe("Owner");
    }

    [Fact]
    public async Task Un_nom_vide_ou_une_fin_avant_le_debut_sont_refuses()
    {
        var organisateur = await CompteAsync();

        var sansNom = await organisateur.PostAsJsonAsync("/v1/events", new
        {
            name = "   ",
            startsAt = DateTimeOffset.UtcNow.AddDays(1),
        });

        sansNom.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(sansNom)).ShouldBe("event.name_required");

        var finAvantDebut = await organisateur.PostAsJsonAsync("/v1/events", new
        {
            name = "Incohérent",
            startsAt = DateTimeOffset.UtcNow.AddDays(2),
            endsAt = DateTimeOffset.UtcNow.AddDays(1),
        });

        finAvantDebut.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(finAvantDebut)).ShouldBe("event.end_before_start");
    }

    [Fact]
    public async Task Le_lien_d_invitation_expose_un_apercu_restreint()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, code) = await CreerAsync(organisateur, "Soirée privée");

        using var inconnu = fixture.CreateClient();

        var apercu = await inconnu.GetAsync(new Uri($"/v1/join/{jeton}", UriKind.Relative));
        apercu.StatusCode.ShouldBe(HttpStatusCode.OK);

        var vue = (await apercu.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        vue.GetProperty("name").GetString().ShouldBe("Soirée privée");
        vue.GetProperty("participantCount").GetInt32().ShouldBe(1);

        // RG-INV-04 : ni liste nominative, ni dépenses, ni discussion avant participation.
        var brut = vue.GetRawText();
        brut.ShouldNotContain("members");
        brut.ShouldNotContain("expenses");
        brut.ShouldNotContain("inviteToken");

        // L'événement lui-même reste inaccessible tant qu'on ne l'a pas rejoint.
        (await inconnu.GetAsync(new Uri($"/v1/events/{eventId}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);

        code.ShouldStartWith("PLAN-");
    }

    [Fact]
    public async Task Un_invite_sans_compte_rejoint_et_declare_sa_presence()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Barbecue");

        using var invite = fixture.CreateClient();

        var adhesion = await invite.PostAsJsonAsync($"/v1/join/{jeton}", new
        {
            displayName = "Julie",
            status = "Going",
        });

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var resultat = (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        resultat.GetProperty("eventId").GetString().ShouldBe(eventId);

        // Un jeton d'invité est remis : c'est la seule identité de cette personne, et
        // c'est lui qui permettra plus tard le rattachement à un compte (RG-AUTH-07).
        var jetonInvite = resultat.GetProperty("guestToken").GetString();
        jetonInvite.ShouldNotBeNullOrEmpty();

        using var avecJeton = fixture.CreateClient();
        avecJeton.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jetonInvite);

        // L'invité voit l'événement rejoint...
        (await avecJeton.GetAsync(new Uri($"/v1/events/{eventId}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        // ...et le décompte des présents l'inclut.
        var membres = await avecJeton.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        membres!.RootElement.EnumerateArray().Count().ShouldBe(2);
        membres.RootElement.EnumerateArray()
            .ShouldContain(m => m.GetProperty("displayName").GetString() == "Julie");
    }

    [Fact]
    public async Task Le_jeton_d_invite_ne_donne_acces_qu_a_son_evenement()
    {
        var organisateur = await CompteAsync();
        var (_, jetonA, _) = await CreerAsync(organisateur, "Événement A");
        var (eventB, _, _) = await CreerAsync(organisateur, "Événement B");

        using var invite = fixture.CreateClient();
        var adhesion = await invite.PostAsJsonAsync($"/v1/join/{jetonA}", new
        {
            displayName = "Julie",
            status = "Going",
        });

        var jetonInvite = (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("guestToken").GetString();

        using var avecJeton = fixture.CreateClient();
        avecJeton.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jetonInvite);

        // EF-INV-04 : un invité est cantonné à l'événement qu'il a rejoint.
        (await avecJeton.GetAsync(new Uri($"/v1/events/{eventB}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Le_code_court_resout_l_evenement()
    {
        var organisateur = await CompteAsync();
        var (_, _, code) = await CreerAsync(organisateur, "Raclette");

        using var inconnu = fixture.CreateClient();

        var direct = await inconnu.GetAsync(new Uri($"/v1/join/code/{code}", UriKind.Relative));
        direct.StatusCode.ShouldBe(HttpStatusCode.OK);

        // La saisie est tolérante : minuscules et absence de préfixe fonctionnent.
        var sansPrefixe = code["PLAN-".Length..].ToLowerInvariant();
        var tolerant = await inconnu.GetAsync(
            new Uri($"/v1/join/code/{sansPrefixe}", UriKind.Relative));

        tolerant.StatusCode.ShouldBe(HttpStatusCode.OK);

        var inexistant = await inconnu.GetAsync(
            new Uri("/v1/join/code/PLAN-ZZZZZZ", UriKind.Relative));

        inexistant.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task La_regeneration_du_lien_invalide_le_precedent()
    {
        var organisateur = await CompteAsync();
        var (eventId, ancienJeton, ancienCode) = await CreerAsync(organisateur, "À protéger");

        var rotation = await organisateur.PostAsync(
            new Uri($"/v1/events/{eventId}/invitation/rotate", UriKind.Relative),
            null);

        rotation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var nouveau = (await rotation.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        nouveau.GetProperty("token").GetString().ShouldNotBe(ancienJeton);

        // Le code court est renouvelé avec le lien : n'en changer qu'un laisserait une
        // porte ouverte.
        nouveau.GetProperty("shortCode").GetString().ShouldNotBe(ancienCode);

        using var inconnu = fixture.CreateClient();
        (await inconnu.GetAsync(new Uri($"/v1/join/{ancienJeton}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Un_evenement_ferme_refuse_les_nouvelles_arrivees()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Complet");

        (await organisateur.PatchAsJsonAsync(
                $"/v1/events/{eventId}/join-enabled",
                new { joinEnabled = false }))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        using var invite = fixture.CreateClient();

        var refus = await invite.PostAsJsonAsync($"/v1/join/{jeton}", new
        {
            displayName = "Trop tard",
            status = "Going",
        });

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("invitation.closed");

        // L'aperçu reste lisible : la personne doit comprendre pourquoi elle ne peut pas
        // entrer, plutôt que de recevoir un 404 trompeur.
        var apercu = await invite.GetAsync(new Uri($"/v1/join/{jeton}", UriKind.Relative));
        apercu.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await apercu.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("joinEnabled").GetBoolean().ShouldBeFalse();
    }

    [Fact]
    public async Task Un_membre_ordinaire_ne_modifie_pas_l_evenement()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Chasse gardée");

        var participant = await CompteAsync();
        await participant.PostAsJsonAsync($"/v1/join/{jeton}", new
        {
            displayName = "Lucas",
            status = "Going",
        });

        var modification = await participant.PatchAsJsonAsync(
            $"/v1/events/{eventId}",
            new { name = "Détourné" });

        modification.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await Code(modification)).ShouldBe("event.not_allowed_to_manage");

        var suppression = await participant.DeleteAsync(
            new Uri($"/v1/events/{eventId}?force=true", UriKind.Relative));

        suppression.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Le_proprietaire_ne_peut_pas_quitter_sans_transferer()
    {
        var organisateur = await CompteAsync();
        var (eventId, _, _) = await CreerAsync(organisateur, "Orpheline");

        var depart = await organisateur.DeleteAsync(
            new Uri($"/v1/events/{eventId}/members/me", UriKind.Relative));

        // RG-ROLE-02 : sans quoi l'événement se retrouverait sans propriétaire.
        depart.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(depart)).ShouldBe("event.owner_must_transfer");
    }

    [Fact]
    public async Task Les_presences_suivent_les_regles_de_decompte()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Décompte");

        // Trois invités : présent en retard, peut-être, absent.
        foreach (var (nom, statut) in new[]
                 {
                     ("Lucas", "Late"),
                     ("Emma", "Maybe"),
                     ("Thomas", "NotGoing"),
                 })
        {
            using var invite = fixture.CreateClient();
            await invite.PostAsJsonAsync($"/v1/join/{jeton}", new
            {
                displayName = nom,
                status = statut,
            });
        }

        var evenement = await organisateur.GetFromJsonAsync<JsonDocument>($"/v1/events/{eventId}");

        // RG-PRES-02 : « arrive plus tard » compte comme présent, avec l'organisateur.
        // RG-PRES-03 : « peut-être » est compté à part.
        evenement!.RootElement.GetProperty("memberCount").GetInt32().ShouldBe(4);
        evenement.RootElement.GetProperty("presentCount").GetInt32().ShouldBe(2);
        evenement.RootElement.GetProperty("maybeCount").GetInt32().ShouldBe(1);
    }

    [Fact]
    public async Task Un_statut_inconnu_est_refuse()
    {
        var organisateur = await CompteAsync();
        var (eventId, _, _) = await CreerAsync(organisateur, "Statuts");

        var refus = await organisateur.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Peut-être-que-oui" });

        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(refus)).ShouldBe("attendance.unknown_status");
    }

    [Fact]
    public async Task Le_nombre_d_accompagnants_est_plafonne()
    {
        var organisateur = await CompteAsync();
        var (eventId, _, _) = await CreerAsync(organisateur, "Accompagnants");

        var refus = await organisateur.PatchAsJsonAsync(
            $"/v1/events/{eventId}/members/me",
            new { status = "Going", extraGuests = 99 });

        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(refus)).ShouldBe("attendance.too_many_guests");
    }

    [Fact]
    public async Task La_suppression_exige_une_confirmation_renforcee()
    {
        var organisateur = await CompteAsync();
        var (eventId, _, _) = await CreerAsync(organisateur, "À supprimer");

        var sansForcer = await organisateur.DeleteAsync(
            new Uri($"/v1/events/{eventId}", UriKind.Relative));

        // RG-EVT-02 : supprimer efface les comptes de tous les participants.
        sansForcer.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(sansForcer)).ShouldBe("event.settlements_pending");

        var avecForce = await organisateur.DeleteAsync(
            new Uri($"/v1/events/{eventId}?force=true", UriKind.Relative));

        avecForce.StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // L'événement supprimé disparaît de la liste et devient inaccessible.
        (await organisateur.GetAsync(new Uri($"/v1/events/{eventId}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Le_transfert_de_propriete_debloque_le_depart_du_proprietaire()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Passation");

        // Un membre avec compte : un invité sans compte ne peut pas devenir propriétaire.
        var repreneur = await CompteAsync();
        await repreneur.PostAsJsonAsync($"/v1/join/{jeton}", new
        {
            displayName = "Lucas",
            status = "Going",
        });

        var membres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var cible = membres!.RootElement.EnumerateArray()
            .Single(m => m.GetProperty("displayName").GetString() == "Lucas")
            .GetProperty("id").GetString();

        // Avant transfert, le propriétaire est prisonnier de son événement.
        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{eventId}/members/me", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);

        var transfert = await organisateur.PostAsync(
            new Uri($"/v1/events/{eventId}/members/{cible}/transfer-ownership", UriKind.Relative),
            null);

        transfert.StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // L'ancien propriétaire devient administrateur, non membre ordinaire : lui
        // retirer tout droit dans le même geste serait absurde.
        var apres = await repreneur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var roles = apres!.RootElement.EnumerateArray()
            .ToDictionary(
                m => m.GetProperty("displayName").GetString()!,
                m => m.GetProperty("role").GetString()!);

        roles["Lucas"].ShouldBe("Owner");
        roles["Organisateur"].ShouldBe("Admin");

        // Le départ est désormais possible.
        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{eventId}/members/me", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task Un_invite_sans_compte_ne_peut_pas_devenir_proprietaire()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Sans compte");

        using var invite = fixture.CreateClient();
        await invite.PostAsJsonAsync($"/v1/join/{jeton}", new
        {
            displayName = "Julie",
            status = "Going",
        });

        var membres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var cible = membres!.RootElement.EnumerateArray()
            .Single(m => m.GetProperty("displayName").GetString() == "Julie")
            .GetProperty("id").GetString();

        var refus = await organisateur.PostAsync(
            new Uri($"/v1/events/{eventId}/members/{cible}/transfer-ownership", UriKind.Relative),
            null);

        // Un invité sans compte ne retrouverait pas l'événement depuis un autre appareil.
        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("event.transfer_needs_account");
    }

    [Fact]
    public async Task Un_administrateur_ne_transfere_pas_la_propriete()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Chasse gardée 2");

        var membre = await CompteAsync();
        await membre.PostAsJsonAsync($"/v1/join/{jeton}", new
        {
            displayName = "Lucas",
            status = "Going",
        });

        var membres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var soi = membres!.RootElement.EnumerateArray()
            .Single(m => m.GetProperty("displayName").GetString() == "Lucas")
            .GetProperty("id").GetString();

        var refus = await membre.PostAsync(
            new Uri($"/v1/events/{eventId}/members/{soi}/transfer-ownership", UriKind.Relative),
            null);

        refus.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await Code(refus)).ShouldBe("event.only_owner_transfers");
    }

    private async Task<HttpClient> CompteAsync()
    {
        var adresse = $"evt-{Guid.CreateVersion7():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = MotDePasse,
            displayName = "Organisateur",
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        return client;
    }

    private static async Task<(string eventId, string token, string shortCode)> CreerAsync(
        HttpClient client,
        string nom)
    {
        var creation = await client.PostAsJsonAsync("/v1/events", new
        {
            name = nom,
            startsAt = DateTimeOffset.UtcNow.AddDays(7),
            address = "Replonges",
        });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var eventId = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;

        var invitation = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/invitation");

        return (
            eventId,
            invitation!.RootElement.GetProperty("token").GetString()!,
            invitation.RootElement.GetProperty("shortCode").GetString()!);
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }
}
