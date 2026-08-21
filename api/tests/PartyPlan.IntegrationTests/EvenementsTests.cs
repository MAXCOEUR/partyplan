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

        var reponse = await CreerBrutAsync(organisateur, new
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

        var sansNom = await CreerBrutAsync(organisateur, new
        {
            name = "   ",
            startsAt = DateTimeOffset.UtcNow.AddDays(1),
        });

        sansNom.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(sansNom)).ShouldBe("event.name_required");

        var finAvantDebut = await CreerBrutAsync(organisateur, new
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
    public async Task Une_session_est_obligatoire_pour_rejoindre()
    {
        var organisateur = await CompteAsync();
        var (_, jeton, code) = await CreerAsync(organisateur, "Privée");
        using var anonyme = fixture.CreateClient();

        (await RejoindreBrutAsync(anonyme, $"/v1/join/{jeton}"))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        (await RejoindreBrutAsync(anonyme, $"/v1/join/code/{code}"))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Le_compte_rejoint_avec_son_nom_et_sans_reponse()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Barbecue");
        var lea = await CompteAsync("Léa Martin");

        var adhesion = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());
        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var resultat = (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        resultat.TryGetProperty("guestToken", out _).ShouldBeFalse();

        var membres = await MembresAsync(organisateur, eventId);
        var membre = membres.EnumerateArray().Single(m => m.GetProperty("displayName").GetString() == "Léa Martin");
        membre.GetProperty("status").GetString().ShouldBe("Unknown");
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

        var participant = await CompteAsync("Trop tard");

        var refus = await RejoindreBrutAsync(participant, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("invitation.closed");

        // L'aperçu reste lisible : la personne doit comprendre pourquoi elle ne peut pas
        // entrer, plutôt que de recevoir un 404 trompeur.
        var apercu = await participant.GetAsync(new Uri($"/v1/join/{jeton}", UriKind.Relative));
        apercu.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await apercu.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("joinEnabled").GetBoolean().ShouldBeFalse();
    }

    [Fact]
    public async Task Un_membre_ordinaire_ne_modifie_pas_l_evenement()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Chasse gardée");

        var participant = await CompteAsync("Lucas");
        await RejoindreBrutAsync(participant, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());

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

        // Les nouveaux membres commencent sans réponse ; chacun déclare ensuite sa présence.
        foreach (var (nom, statut) in new[]
                 {
                     ("Lucas", "Late"),
                     ("Emma", "Maybe"),
                     ("Thomas", "NotGoing"),
                 })
        {
            var participant = await CompteAsync(nom);
            (await RejoindreBrutAsync(participant, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString()))
                .StatusCode.ShouldBe(HttpStatusCode.OK);
            (await participant.PatchAsJsonAsync(
                    $"/v1/events/{eventId}/members/me",
                    new { status = statut }))
                .StatusCode.ShouldBe(HttpStatusCode.OK);
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

        var repreneur = await CompteAsync("Lucas");
        await RejoindreBrutAsync(repreneur, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());

        var membres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var cible = membres!.RootElement.EnumerateArray()
            .Single(m => m.GetProperty("displayName").GetString() == "Lucas")
            .GetProperty("id").GetString();

        // Avant transfert, le propriétaire est prisonnier de son événement.
        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{eventId}/members/me", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);

        var transfert = await TransfererBrutAsync(organisateur, eventId, cible!, Guid.CreateVersion7().ToString());

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
    public async Task Un_administrateur_ne_transfere_pas_la_propriete()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Chasse gardée 2");

        var membre = await CompteAsync("Lucas");
        await RejoindreBrutAsync(membre, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());

        var membres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var soi = membres!.RootElement.EnumerateArray()
            .Single(m => m.GetProperty("displayName").GetString() == "Lucas")
            .GetProperty("id").GetString();

        var refus = await TransfererBrutAsync(membre, eventId, soi!, Guid.CreateVersion7().ToString());

        refus.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await Code(refus)).ShouldBe("event.only_owner_transfers");
    }

    private async Task<HttpClient> CompteAsync(string nomAffiche = "Organisateur")
    {
        var adresse = $"evt-{Guid.CreateVersion7():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse,
            password = MotDePasse,
            displayName = nomAffiche,
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        return client;
    }

    /// <summary>
    /// Crée un événement. L'en-tête d'idempotence est obligatoire (§8.1) : un assistant
    /// évite de le répéter dans chaque test, et surtout de l'oublier.
    /// </summary>
    internal static Task<HttpResponseMessage> CreerBrutAsync(HttpClient client, object corps)
    {
        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri("/v1/events", UriKind.Relative))
        {
            Content = JsonContent.Create(corps),
        };

        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        return client.SendAsync(requete);
    }

    private static async Task<(string eventId, string token, string shortCode)> CreerAsync(
        HttpClient client,
        string nom)
    {
        var creation = await CreerBrutAsync(client, new
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

    [Fact]
    public async Task Adhesion_rejouee_avec_la_meme_cle_ne_cree_pas_deux_membres()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Rejeu d'adhésion");
        var lea = await CompteAsync("Léa");
        var cle = Guid.CreateVersion7().ToString();

        var premiere = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", cle);
        var seconde = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", cle);

        premiere.StatusCode.ShouldBe(HttpStatusCode.OK);

        // Le rejeu rend la réponse mémorisée. C'est exactement ce qui se produit au
        // retour du réseau, quand le client vide sa file d'écritures.
        seconde.StatusCode.ShouldBe(HttpStatusCode.OK);

        var premierResultat = (await premiere.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        var secondResultat = (await seconde.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        secondResultat.GetProperty("memberId").GetString().ShouldBe(premierResultat.GetProperty("memberId").GetString());

        (await MembresAsync(organisateur, eventId)).EnumerateArray()
            .Count(m => m.GetProperty("displayName").GetString() == "Léa")
            .ShouldBe(1);
    }

    [Fact]
    public async Task Une_nouvelle_cle_pour_le_meme_compte_conserve_la_presence()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Présence conservée");
        var lea = await CompteAsync("Léa");

        var premiere = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());
        premiere.StatusCode.ShouldBe(HttpStatusCode.OK);
        var memberId = (await premiere.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement
            .GetProperty("memberId").GetString();

        (await lea.PatchAsJsonAsync(
                $"/v1/events/{eventId}/members/me",
                new { status = "Maybe" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var seconde = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());
        seconde.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await seconde.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement
            .GetProperty("memberId").GetString().ShouldBe(memberId);

        var membre = (await MembresAsync(organisateur, eventId)).EnumerateArray()
            .Single(m => m.GetProperty("id").GetString() == memberId);
        membre.GetProperty("status").GetString().ShouldBe("Maybe");
    }

    [Fact]
    public async Task Un_compte_supprime_est_refuse_pour_rejoindre()
    {
        var organisateur = await CompteAsync();
        var (_, jeton, _) = await CreerAsync(organisateur, "Compte supprimé");
        var ancienCompte = await CompteAsync("Ancien participant");
        var profil = await ancienCompte.GetFromJsonAsync<JsonDocument>("/v1/me");
        var userId = Guid.Parse(profil!.RootElement.GetProperty("id").GetString()!);

        await fixture.WithDatabaseAsync(async db =>
        {
            var utilisateur = db.Users.Single(u => u.Id == userId);
            utilisateur.DeletedAt = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync();
        });

        (await RejoindreBrutAsync(
                ancienCompte,
                $"/v1/join/{jeton}",
                Guid.CreateVersion7().ToString()))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Adhesion_sans_cle_d_idempotence_est_refusee()
    {
        var organisateur = await CompteAsync();
        var (_, jeton, _) = await CreerAsync(organisateur, "Sans clé");

        var lea = await CompteAsync("Léa");

        var reponse = await RejoindreBrutAsync(lea, $"/v1/join/{jeton}");

        reponse.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Transfert_de_propriete_rejoue_ne_change_rien()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Rejeu de transfert");

        var repreneur = await CompteAsync("Lucas");
        await RejoindreBrutAsync(repreneur, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString());

        var avant = await MembresAsync(organisateur, eventId);
        var cible = avant.EnumerateArray()
            .Single(m => m.GetProperty("displayName").GetString() == "Lucas")
            .GetProperty("id").GetString()!;

        var cle = Guid.CreateVersion7().ToString();

        (await TransfererBrutAsync(organisateur, eventId, cible, cle))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // Rejoué, le transfert rend la réponse mémorisée. Sans idempotence, le second
        // appel échouerait — l'appelant n'étant plus propriétaire — et le client
        // afficherait une erreur pour une action qui a pourtant abouti.
        (await TransfererBrutAsync(organisateur, eventId, cible, cle))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var apres = await MembresAsync(repreneur, eventId);
        apres.EnumerateArray()
            .Count(m => m.GetProperty("role").GetString() == "Owner")
            .ShouldBe(1);
        apres.EnumerateArray()
            .Single(m => m.GetProperty("role").GetString() == "Owner")
            .GetProperty("displayName").GetString().ShouldBe("Lucas");
    }

    [Fact]
    public async Task Deux_comptes_creent_deux_membres_et_modifient_chacun_leur_propre_presence()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton, _) = await CreerAsync(organisateur, "Deux comptes");

        var lea = await CompteAsync("Léa");
        var tom = await CompteAsync("Tom");

        (await RejoindreBrutAsync(lea, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString()))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
        (await RejoindreBrutAsync(tom, $"/v1/join/{jeton}", Guid.CreateVersion7().ToString()))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        (await lea.PatchAsJsonAsync(
                $"/v1/events/{eventId}/members/me",
                new { status = "NotGoing" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        (await tom.PatchAsJsonAsync(
                $"/v1/events/{eventId}/members/me",
                new { status = "Maybe" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var membres = await MembresAsync(organisateur, eventId);
        var parNom = membres.EnumerateArray()
            .ToDictionary(
                m => m.GetProperty("displayName").GetString()!,
                m => m.GetProperty("status").GetString()!);

        parNom["Léa"].ShouldBe("NotGoing");
        parNom["Tom"].ShouldBe("Maybe");
    }

    [Fact]
    public async Task Le_code_court_permet_de_rejoindre_et_pas_seulement_de_regarder()
    {
        var organisateur = await CompteAsync();
        var (eventId, _, code) = await CreerAsync(organisateur, "Code court");
        var zoe = await CompteAsync("Zoé");

        // Saisie tolérante : minuscules, espaces, absence de préfixe.
        var adhesion = await RejoindreBrutAsync(
            zoe,
            $"/v1/join/code/{code[5..].ToLowerInvariant()}",
            Guid.CreateVersion7().ToString());

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var resultat = (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        resultat.GetProperty("eventId").GetString().ShouldBe(eventId);

        resultat.TryGetProperty("guestToken", out _).ShouldBeFalse();

        var membres = await MembresAsync(organisateur, eventId);
        membres.EnumerateArray()
            .ShouldContain(m => m.GetProperty("displayName").GetString() == "Zoé");
    }

    [Fact]
    public async Task Un_code_court_inconnu_ne_laisse_pas_rejoindre()
    {
        var intrus = await CompteAsync("Intrus");

        (await RejoindreBrutAsync(
                intrus,
                "/v1/join/code/ZZZZZZ",
                Guid.CreateVersion7().ToString()))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    /// <summary>
    /// Rejoint un événement. L'en-tête d'idempotence est obligatoire : cette écriture
    /// peut être mise en file par le client hors ligne (NF-OFFLINE-01), et son rejeu
    /// ne doit jamais produire un second membre.
    /// </summary>
    internal static Task<HttpResponseMessage> RejoindreBrutAsync(
        HttpClient client,
        string chemin,
        string? cle = null)
    {
        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri(chemin, UriKind.Relative))
        {
            Content = null,
        };

        if (cle is not null)
        {
            requete.Headers.Add("Idempotency-Key", cle);
        }

        return client.SendAsync(requete);
    }

    /// <summary>Transfert de propriété, idempotent pour la même raison.</summary>
    internal static Task<HttpResponseMessage> TransfererBrutAsync(
        HttpClient client,
        string eventId,
        string membreId,
        string? cle = null)
    {
        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/events/{eventId}/members/{membreId}/transfer-ownership", UriKind.Relative));

        if (cle is not null)
        {
            requete.Headers.Add("Idempotency-Key", cle);
        }

        return client.SendAsync(requete);
    }

    private static async Task<JsonElement> MembresAsync(HttpClient client, string eventId)
    {
        var membres = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        return membres!.RootElement.Clone();
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }
}

/// <summary>
/// Idempotence des créations (§8.1).
/// <para>
/// Sur réseau mobile, un double envoi est courant. Sans idempotence, l'organisateur se
/// retrouve avec deux soirées et a peut-être déjà partagé le mauvais lien.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class IdempotenceTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task La_cle_d_idempotence_est_obligatoire_sur_la_creation()
    {
        var client = await CompteAsync();

        var sansCle = await client.PostAsJsonAsync("/v1/events", new
        {
            name = "Sans clé",
            startsAt = DateTimeOffset.UtcNow.AddDays(3),
        });

        // L'en-tête est obligatoire et non facultatif : le rendre optionnel ne
        // protégerait pas les clients qui l'omettent, c'est-à-dire ceux qui en ont besoin.
        sansCle.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await CodeDe(sansCle)).ShouldBe("idempotency.key_required");
    }

    [Fact]
    public async Task Une_meme_cle_avec_le_meme_corps_rejoue_la_reponse()
    {
        var client = await CompteAsync();
        var cle = Guid.CreateVersion7().ToString();
        var corps = new
        {
            name = "Soirée unique",
            startsAt = DateTimeOffset.Parse("2026-09-12T18:00:00Z", null),
        };

        var premiere = await Envoyer(client, cle, corps);
        var seconde = await Envoyer(client, cle, corps);

        premiere.StatusCode.ShouldBe(HttpStatusCode.OK);
        seconde.StatusCode.ShouldBe(HttpStatusCode.OK);

        seconde.Headers.Contains("Idempotency-Replayed").ShouldBeTrue();

        // Même identifiant : la réponse d'origine est rejouée, aucune seconde soirée
        // n'est créée.
        var premierId = await IdDe(premiere);
        (await IdDe(seconde)).ShouldBe(premierId);

        var liste = await client.GetFromJsonAsync<JsonDocument>("/v1/events");
        liste!.RootElement.EnumerateArray()
            .Count(e => e.GetProperty("name").GetString() == "Soirée unique")
            .ShouldBe(1);
    }

    [Fact]
    public async Task Une_meme_cle_avec_un_corps_different_est_un_conflit()
    {
        var client = await CompteAsync();
        var cle = Guid.CreateVersion7().ToString();

        var premiere = await Envoyer(client, cle, new
        {
            name = "Première",
            startsAt = DateTimeOffset.Parse("2026-09-12T18:00:00Z", null),
        });

        // Sans cette assertion, un échec de la première requête ferait passer la seconde
        // pour une clé neuve, et le test échouerait pour une raison trompeuse.
        premiere.StatusCode.ShouldBe(HttpStatusCode.OK, await premiere.Content.ReadAsStringAsync());

        var conflit = await Envoyer(client, cle, new
        {
            name = "Seconde",
            startsAt = DateTimeOffset.Parse("2026-09-13T18:00:00Z", null),
        });

        // C'est une erreur du client. La traiter comme une réémission créerait la soirée
        // que l'idempotence est censée empêcher.
        conflit.StatusCode.ShouldBe(HttpStatusCode.Conflict);
        (await CodeDe(conflit)).ShouldBe("idempotency.key_reused");
    }

    [Fact]
    public async Task Deux_cles_differentes_creent_deux_evenements()
    {
        var client = await CompteAsync();
        var corps = new
        {
            name = "Série",
            startsAt = DateTimeOffset.Parse("2026-09-12T18:00:00Z", null),
        };

        var premiere = await Envoyer(client, Guid.CreateVersion7().ToString(), corps);
        var seconde = await Envoyer(client, Guid.CreateVersion7().ToString(), corps);

        // L'idempotence ne doit pas empêcher deux créations volontaires identiques.
        (await IdDe(premiere)).ShouldNotBe(await IdDe(seconde));
    }

    [Fact]
    public async Task Un_echec_n_est_pas_memorise()
    {
        var client = await CompteAsync();
        var cle = Guid.CreateVersion7().ToString();

        var invalide = await Envoyer(client, cle, new
        {
            name = "  ",
            startsAt = DateTimeOffset.Parse("2026-09-12T18:00:00Z", null),
        });

        invalide.StatusCode.ShouldBe(HttpStatusCode.BadRequest);

        // Mémoriser l'échec empêcherait de corriger la requête et de la renvoyer avec la
        // même clé — ce que fait naturellement un client après un message d'erreur.
        var corrigee = await Envoyer(client, cle, new
        {
            name = "Corrigée",
            startsAt = DateTimeOffset.Parse("2026-09-12T18:00:00Z", null),
        });

        corrigee.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Deux_comptes_peuvent_reutiliser_la_meme_cle()
    {
        var cle = "une-cle-partagee-par-megarde";
        var corps = new
        {
            name = "Indépendant",
            startsAt = DateTimeOffset.Parse("2026-09-12T18:00:00Z", null),
        };

        var premier = await Envoyer(await CompteAsync(), cle, corps);
        var second = await Envoyer(await CompteAsync(), cle, corps);

        // La clé est propre à un appelant : deux utilisateurs ne doivent pas se gêner.
        premier.StatusCode.ShouldBe(HttpStatusCode.OK);
        second.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await IdDe(premier)).ShouldNotBe(await IdDe(second));
    }

    private static Task<HttpResponseMessage> Envoyer(HttpClient client, string cle, object corps)
    {
        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri("/v1/events", UriKind.Relative))
        {
            Content = JsonContent.Create(corps),
        };

        requete.Headers.Add("Idempotency-Key", cle);

        return client.SendAsync(requete);
    }

    private async Task<HttpClient> CompteAsync()
    {
        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = $"idem-{Guid.CreateVersion7():N}@partyplan.test",
            password = "Trombone-Nuage-42x",
            displayName = "Organisateur",
        });

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        return client;
    }

    private static async Task<string?> IdDe(HttpResponseMessage reponse) =>
        (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString();

    private static async Task<string?> CodeDe(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }
}
