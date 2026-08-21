namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Discussion d'un événement : fil, réactions, réponses, mentions, épingles.
/// <para>
/// Le cloisonnement est vérifié comme partout ailleurs : un non-membre reçoit 404, pas
/// « accès refusé ». Révéler l'existence d'une discussion privée serait déjà une fuite
/// (RG-SEC-02).
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class DiscussionTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Un_message_envoye_apparait_dans_le_fil()
    {
        var (client, evenement, _) = await EvenementAsync();

        var envoi = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { body = "On prend quoi comme musique ?" });

        envoi.StatusCode.ShouldBe(HttpStatusCode.OK);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var messages = fil!.RootElement.GetProperty("items");

        messages.GetArrayLength().ShouldBe(1);
        messages[0].GetProperty("body").GetString().ShouldBe("On prend quoi comme musique ?");
        messages[0].GetProperty("mine").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task Un_message_vide_et_sans_piece_jointe_est_refuse()
    {
        var (client, evenement, _) = await EvenementAsync();

        var envoi = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { body = "   " });

        envoi.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(envoi)).ShouldBe("message.empty");
    }

    [Fact]
    public async Task Le_fil_est_rendu_du_plus_ancien_au_plus_recent()
    {
        // Une conversation se lit dans l'ordre où elle s'est tenue. L'inverser
        // obligerait à remonter pour comprendre une réponse.
        var (client, evenement, _) = await EvenementAsync();

        foreach (var texte in new[] { "premier", "deuxième", "troisième" })
        {
            (await client.PostAsJsonAsync(Chemin(evenement), new { body = texte }))
                .StatusCode.ShouldBe(HttpStatusCode.OK);
        }

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var messages = fil!.RootElement.GetProperty("items");

        messages[0].GetProperty("body").GetString().ShouldBe("premier");
        messages[2].GetProperty("body").GetString().ShouldBe("troisième");
    }

    [Fact]
    public async Task Une_reponse_porte_le_message_cite()
    {
        var (client, evenement, _) = await EvenementAsync();

        var premier = await Envoyer(client, evenement, "On prend quoi comme musique ?");

        var reponse = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { body = "Ma playlist", replyToMessageId = premier });

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var cite = fil!.RootElement.GetProperty("items")[1].GetProperty("replyTo");

        cite.GetProperty("id").GetGuid().ShouldBe(premier);
        cite.GetProperty("body").GetString().ShouldBe("On prend quoi comme musique ?");
    }

    [Fact]
    public async Task Une_mention_est_enregistree_et_rendue()
    {
        // Enregistrée plutôt que relue dans le texte : c'est ce qui permettra de
        // notifier la personne citée sans réanalyser l'historique.
        var (client, evenement, moi) = await EvenementAsync();

        var envoi = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { body = "tu apportes l'enceinte ?", mentionedMemberIds = new[] { moi } });

        envoi.StatusCode.ShouldBe(HttpStatusCode.OK);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var mentions = fil!.RootElement.GetProperty("items")[0].GetProperty("mentions");

        mentions.GetArrayLength().ShouldBe(1);
        mentions[0].GetProperty("memberId").GetGuid().ShouldBe(moi);
    }

    [Fact]
    public async Task Une_mention_d_un_non_membre_est_refusee()
    {
        // Citer quelqu'un d'un autre événement le notifierait d'une soirée à laquelle
        // il n'appartient pas.
        var (client, evenement, _) = await EvenementAsync();

        var envoi = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { body = "coucou", mentionedMemberIds = new[] { Guid.NewGuid() } });

        envoi.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(envoi)).ShouldBe("message.unknown_mention");
    }

    [Fact]
    public async Task Une_reaction_se_pose_et_se_retire()
    {
        var (client, evenement, _) = await EvenementAsync();
        var message = await Envoyer(client, evenement, "on y va");

        (await client.PutAsJsonAsync(
                new Uri($"{Chemin(evenement)}/{message}/reactions", UriKind.Relative),
                new { emoji = "🎉" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var reactions = fil!.RootElement.GetProperty("items")[0].GetProperty("reactions");

        reactions.GetArrayLength().ShouldBe(1);
        reactions[0].GetProperty("emoji").GetString().ShouldBe("🎉");
        reactions[0].GetProperty("count").GetInt32().ShouldBe(1);
        reactions[0].GetProperty("mine").GetBoolean().ShouldBeTrue();

        // La même réaction posée deux fois la retire : c'est un interrupteur, et deux
        // appuis ne doivent pas produire deux pastilles.
        (await client.PutAsJsonAsync(
                new Uri($"{Chemin(evenement)}/{message}/reactions", UriKind.Relative),
                new { emoji = "🎉" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var apres = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        apres!.RootElement.GetProperty("items")[0]
            .GetProperty("reactions").GetArrayLength().ShouldBe(0);
    }

    [Fact]
    public async Task Seul_l_auteur_modifie_son_message()
    {
        var (client, evenement, _) = await EvenementAsync();
        var message = await Envoyer(client, evenement, "faute de frappe");

        var correction = await client.PatchAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{message}", UriKind.Relative),
            new { body = "corrigé" });

        correction.StatusCode.ShouldBe(HttpStatusCode.OK);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var vue = fil!.RootElement.GetProperty("items")[0];

        vue.GetProperty("body").GetString().ShouldBe("corrigé");
        // La modification est visible : un message réécrit en silence permettrait de
        // faire dire à quelqu'un le contraire de ce qu'il a écrit.
        vue.GetProperty("edited").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task Un_message_supprime_laisse_une_trace_sans_son_contenu()
    {
        var (client, evenement, _) = await EvenementAsync();
        var message = await Envoyer(client, evenement, "à effacer");

        (await client.DeleteAsync(new Uri($"{Chemin(evenement)}/{message}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var vue = fil!.RootElement.GetProperty("items")[0];

        // La place du message subsiste : les réponses qui le citent resteraient sinon
        // incompréhensibles.
        vue.GetProperty("deleted").GetBoolean().ShouldBeTrue();
        vue.GetProperty("body").ValueKind.ShouldBe(JsonValueKind.Null);
    }

    [Fact]
    public async Task Un_non_membre_ne_voit_pas_la_discussion()
    {
        var (_, evenement, _) = await EvenementAsync();
        var (etranger, _, _) = await EvenementAsync();

        var refus = await etranger.GetAsync(new Uri(Chemin(evenement), UriKind.Relative));

        // 404 et non 403 : « accès refusé » confirmerait que l'événement existe.
        refus.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Un_message_s_epingle_avec_ou_sans_dossier()
    {
        var (client, evenement, _) = await EvenementAsync();
        var message = await Envoyer(client, evenement, "code portail 4589B");

        // Sans dossier : classer est un travail, et l'imposer ferait renoncer à
        // épingler.
        var sansDossier = await client.PostAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{message}/pin", UriKind.Relative),
            new { folderId = (Guid?)null });

        sansDossier.StatusCode.ShouldBe(HttpStatusCode.OK);

        var epingles = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/pins");

        epingles!.RootElement.GetProperty("items").GetArrayLength().ShouldBe(1);
        epingles.RootElement.GetProperty("items")[0]
            .GetProperty("folderId").ValueKind.ShouldBe(JsonValueKind.Null);
    }

    [Fact]
    public async Task Un_dossier_se_cree_et_recoit_des_epingles()
    {
        var (client, evenement, _) = await EvenementAsync();
        var message = await Envoyer(client, evenement, "adresse : 12 rue des Lilas");

        var dossier = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{evenement}/pins/folders", UriKind.Relative),
            new { name = "Adresses" });

        dossier.StatusCode.ShouldBe(HttpStatusCode.OK);
        var dossierId = (await dossier.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        (await client.PostAsJsonAsync(
                new Uri($"{Chemin(evenement)}/{message}/pin", UriKind.Relative),
                new { folderId = dossierId }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var epingles = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/pins?folderId={dossierId}");

        var premiere = epingles!.RootElement.GetProperty("items")[0];
        premiere.GetProperty("folderId").GetGuid().ShouldBe(dossierId);
        premiere.GetProperty("message").GetProperty("body").GetString()
            .ShouldBe("adresse : 12 rue des Lilas");
    }

    [Fact]
    public async Task Deux_dossiers_de_meme_nom_sont_refuses()
    {
        // Deux dossiers « Musique » rendraient le rangement ambigu.
        var (client, evenement, _) = await EvenementAsync();

        (await client.PostAsJsonAsync(
                new Uri($"/v1/events/{evenement}/pins/folders", UriKind.Relative),
                new { name = "Musique" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var doublon = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{evenement}/pins/folders", UriKind.Relative),
            new { name = "Musique" });

        doublon.StatusCode.ShouldBe(HttpStatusCode.Conflict);
        (await Code(doublon)).ShouldBe("pin.folder_exists");
    }

    [Fact]
    public async Task Une_epingle_se_retire()
    {
        var (client, evenement, _) = await EvenementAsync();
        var message = await Envoyer(client, evenement, "à ne pas garder");

        (await client.PostAsJsonAsync(
                new Uri($"{Chemin(evenement)}/{message}/pin", UriKind.Relative),
                new { folderId = (Guid?)null }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        (await client.DeleteAsync(
                new Uri($"{Chemin(evenement)}/{message}/pin", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var epingles = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/pins");

        epingles!.RootElement.GetProperty("items").GetArrayLength().ShouldBe(0);
    }

    [Fact]
    public async Task Une_image_deposee_rend_une_adresse_utilisable()
    {
        var (client, evenement, _) = await EvenementAsync();

        using var contenu = new MultipartFormDataContent();
        var fichier = new ByteArrayContent(ImagePng());
        fichier.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        contenu.Add(fichier, "file", "photo.png");

        var depot = await client.PostAsync(
            new Uri($"{Chemin(evenement)}/images", UriKind.Relative),
            contenu);

        depot.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await depot.Content.ReadFromJsonAsync<JsonDocument>();
        var adresse = corps!.RootElement.GetProperty("url").GetString();

        // Réencodée en WebP : c'est ce réencodage qui supprime les métadonnées EXIF,
        // dont la géolocalisation qu'un téléphone inscrit dans chaque photo.
        adresse.ShouldNotBeNull();
        adresse.ShouldEndWith(".webp");

        // Puis jointe à un message, elle apparaît dans le fil.
        var envoi = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { attachmentUrl = adresse });

        envoi.StatusCode.ShouldBe(HttpStatusCode.OK);

        var fil = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        fil!.RootElement.GetProperty("items")[0]
            .GetProperty("attachmentUrl").GetString().ShouldBe(adresse);
    }

    [Fact]
    public async Task Un_fichier_qui_n_est_pas_une_image_est_refuse()
    {
        // Le type déclaré ne fait pas foi : c'est le décodage qui valide, sans quoi un
        // exécutable renommé en .png serait accepté et servi à tout l'événement.
        var (client, evenement, _) = await EvenementAsync();

        using var contenu = new MultipartFormDataContent();
        var fichier = new ByteArrayContent([0x4D, 0x5A, 0x90, 0x00]);
        fichier.Headers.ContentType = new MediaTypeHeaderValue("image/png");
        contenu.Add(fichier, "file", "programme.png");

        var depot = await client.PostAsync(
            new Uri($"{Chemin(evenement)}/images", UriKind.Relative),
            contenu);

        depot.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(depot)).ShouldBe("message.not_an_image");
    }

    [Fact]
    public async Task Un_message_ne_portant_qu_une_image_est_accepte()
    {
        // Une photo se passe de légende : exiger du texte obligerait à écrire « voilà ».
        var (client, evenement, _) = await EvenementAsync();

        var envoi = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { attachmentUrl = "http://localhost:5080/media/events/x/abc.webp" });

        envoi.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    /// <summary>
    /// PNG valide de quatre pixels sur quatre, en couleurs vraies. Assez petit pour un
    /// test, assez complet pour être réellement décodé — c'est le décodage qui valide
    /// le fichier côté serveur.
    /// </summary>
    private static byte[] ImagePng() => Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEElEQVR4nGM4YdMDRwzEcQCOEhkBYbxwrwAAAABJRU5ErkJggg==");

    // ------------------------------------------------------------------ aides ----

    private static string Chemin(Guid evenement) => $"/v1/events/{evenement}/messages";

    private static async Task<Guid> Envoyer(HttpClient client, Guid evenement, string texte)
    {
        var reponse = await client.PostAsJsonAsync(Chemin(evenement), new { body = texte });
        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.GetProperty("id").GetGuid();
    }

    /// <summary>Compte neuf, événement neuf, et l'identifiant de membre de l'appelant.</summary>
    private async Task<(HttpClient client, Guid evenement, Guid moi)> EvenementAsync()
    {
        var adresse = $"discussion-{Guid.NewGuid():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();
        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = adresse, password = MotDePasse, displayName = "Hôte" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);
        var jetons = await inscription.Content.ReadFromJsonAsync<JsonDocument>();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            jetons!.RootElement.GetProperty("accessToken").GetString());
        // Posée sur la seule requête qui l'exige : réutilisée pour tout le client,
        // elle ferait rejouer la première réponse à chaque appel suivant.
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        var creation = await client.PostAsJsonAsync(
            new Uri("/v1/events", UriKind.Relative),
            new { name = "Crémaillère", startsAt = DateTimeOffset.UtcNow.AddDays(10) });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);
        var evenement = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        client.DefaultRequestHeaders.Remove("Idempotency-Key");

        var moi = Guid.Empty;
        await fixture.WithDatabaseAsync(async db =>
        {
            // IgnoreQueryFilters : le cloisonnement passe par un filtre global sur les
            // événements autorisés de la requête en cours. Hors requête HTTP, ce filtre
            // ne laisse rien passer.
            moi = await db.EventMembers
                .IgnoreQueryFilters()
                .Where(m => m.EventId == evenement)
                .Select(m => m.Id)
                .SingleAsync();
        });

        return (client, evenement, moi);
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.TryGetProperty("code", out var code)
            ? code.GetString()
            : null;
    }
}
