namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Pagination du fil et suivi de lecture.
/// <para>
/// Un fil rendu en entier tient tant que la soirée est jeune. Après trois semaines de
/// conversation, chaque ouverture de l'onglet télécharge tout l'historique : ce sont les
/// derniers messages qui intéressent, et le reste se demande en remontant.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FilPaginationTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Le_fil_ne_rend_que_les_derniers_messages()
    {
        var (client, evenement, _) = await EvenementAsync();

        for (var i = 1; i <= 12; i++)
        {
            await Envoyer(client, evenement, $"message {i}");
        }

        var fil = await Fil(client, evenement, "?limit=5");
        var messages = fil.GetProperty("items");

        messages.GetArrayLength().ShouldBe(5);
        // Les derniers, et rendus dans l'ordre où ils ont été écrits.
        messages[0].GetProperty("body").GetString().ShouldBe("message 8");
        messages[4].GetProperty("body").GetString().ShouldBe("message 12");
        fil.GetProperty("hasMore").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task La_suite_se_demande_en_remontant()
    {
        var (client, evenement, _) = await EvenementAsync();

        for (var i = 1; i <= 12; i++)
        {
            await Envoyer(client, evenement, $"message {i}");
        }

        var derniers = await Fil(client, evenement, "?limit=5");
        var plusAncien = derniers.GetProperty("items")[0].GetProperty("id").GetGuid();

        var precedents = await Fil(client, evenement, $"?limit=5&before={plusAncien}");
        var messages = precedents.GetProperty("items");

        messages.GetArrayLength().ShouldBe(5);
        messages[0].GetProperty("body").GetString().ShouldBe("message 3");
        messages[4].GetProperty("body").GetString().ShouldBe("message 7");
        precedents.GetProperty("hasMore").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task Le_debut_du_fil_se_reconnait()
    {
        var (client, evenement, _) = await EvenementAsync();

        await Envoyer(client, evenement, "seul message");

        var fil = await Fil(client, evenement, "?limit=5");

        fil.GetProperty("items").GetArrayLength().ShouldBe(1);
        // Sans cette indication, l'application redemanderait indéfiniment une page qui
        // n'existe pas, à chaque fois que la personne remonte le fil.
        fil.GetProperty("hasMore").GetBoolean().ShouldBeFalse();
    }

    [Fact]
    public async Task Une_limite_demesuree_est_ramenee_a_un_plafond()
    {
        // Sans plafond, un appelant demande le fil entier en passant limit=100000, et la
        // pagination ne protège plus rien.
        var (client, evenement, _) = await EvenementAsync();

        await Envoyer(client, evenement, "un");

        var fil = await Fil(client, evenement, "?limit=100000");

        fil.GetProperty("items").GetArrayLength().ShouldBe(1);
    }

    [Fact]
    public async Task Le_fil_dit_ce_qui_reste_a_lire()
    {
        // Ouvrir la discussion en bas convient quand on l'a quittée à jour. Après une
        // absence, c'est au premier message non lu qu'il faut arriver — sinon il faut
        // remonter à l'aveugle pour retrouver où on s'était arrêté.
        var (hote, evenement, _) = await EvenementAsync();
        var (invite, _) = await SecondMembreAsync(hote, evenement);

        var premier = await Envoyer(hote, evenement, "premier");
        await Envoyer(hote, evenement, "deuxième");

        var vuParInvite = await Fil(invite, evenement);

        vuParInvite.GetProperty("unreadCount").GetInt32().ShouldBe(2);
        vuParInvite.GetProperty("firstUnreadId").GetGuid().ShouldBe(premier);
    }

    [Fact]
    public async Task Ce_qui_est_lu_ne_revient_pas_comme_non_lu()
    {
        var (hote, evenement, _) = await EvenementAsync();
        var (invite, _) = await SecondMembreAsync(hote, evenement);

        await Envoyer(hote, evenement, "premier");
        var dernier = await Envoyer(hote, evenement, "deuxième");

        var marquage = await invite.PostAsJsonAsync(
            new Uri(Chemin(evenement) + "/read", UriKind.Relative),
            new { messageId = dernier });

        marquage.StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var apres = await Fil(invite, evenement);

        apres.GetProperty("unreadCount").GetInt32().ShouldBe(0);
        apres.TryGetProperty("firstUnreadId", out var premierNonLu).ShouldBeTrue();
        premierNonLu.ValueKind.ShouldBe(JsonValueKind.Null);
    }

    [Fact]
    public async Task Le_marqueur_de_lecture_ne_recule_jamais()
    {
        // Deux appareils lisent le même fil : le téléphone resté sur un vieux message
        // ne doit pas faire réapparaître comme non lu ce que l'ordinateur a déjà lu.
        var (hote, evenement, _) = await EvenementAsync();
        var (invite, _) = await SecondMembreAsync(hote, evenement);

        var premier = await Envoyer(hote, evenement, "premier");
        var dernier = await Envoyer(hote, evenement, "deuxième");

        (await invite.PostAsJsonAsync(
            new Uri(Chemin(evenement) + "/read", UriKind.Relative),
            new { messageId = dernier })).StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await invite.PostAsJsonAsync(
            new Uri(Chemin(evenement) + "/read", UriKind.Relative),
            new { messageId = premier })).StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await Fil(invite, evenement)).GetProperty("unreadCount").GetInt32().ShouldBe(0);
    }

    [Fact]
    public async Task Ses_propres_messages_ne_sont_jamais_non_lus()
    {
        // Écrire, c'est avoir lu : un compteur qui s'incrémente sur ses propres envois
        // afficherait une pastille que rien ne peut faire disparaître.
        var (client, evenement, _) = await EvenementAsync();

        await Envoyer(client, evenement, "de moi");

        (await Fil(client, evenement)).GetProperty("unreadCount").GetInt32().ShouldBe(0);
    }

    [Fact]
    public async Task Le_premier_non_lu_est_rendu_meme_loin_dans_le_fil()
    {
        // Le rattrapage est le point délicat : si la page ne contient que les derniers
        // messages, le premier non lu peut se trouver au-dessus, et l'application n'a
        // rien pour se positionner.
        var (hote, evenement, _) = await EvenementAsync();
        var (invite, _) = await SecondMembreAsync(hote, evenement);

        var premier = await Envoyer(hote, evenement, "message 1");

        for (var i = 2; i <= 8; i++)
        {
            await Envoyer(hote, evenement, $"message {i}");
        }

        var fil = await Fil(invite, evenement, "?limit=3");

        fil.GetProperty("unreadCount").GetInt32().ShouldBe(8);
        fil.GetProperty("firstUnreadId").GetGuid().ShouldBe(premier);
        // La page reste bornée : c'est à l'application de remonter jusque-là.
        fil.GetProperty("items").GetArrayLength().ShouldBe(3);
    }

    // ------------------------------------------------------------------ aides ----

    /// <summary>Second membre de l'événement, avec son propre client authentifié.</summary>
    private async Task<(HttpClient client, Guid membre)> SecondMembreAsync(
        HttpClient hote,
        Guid evenement)
    {
        var invitation = await hote.GetFromJsonAsync<JsonDocument>(
            new Uri($"/v1/events/{evenement}/invitation", UriKind.Relative));
        var jetonInvitation = invitation!.RootElement.GetProperty("token").GetString();

        var adresse = $"lecteur-{Guid.NewGuid():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();
        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = adresse, password = MotDePasse, displayName = "Lecteur" });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);
        var jetons = await inscription.Content.ReadFromJsonAsync<JsonDocument>();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            jetons!.RootElement.GetProperty("accessToken").GetString());
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        var adhesion = await client.PostAsJsonAsync(
            new Uri($"/v1/join/{jetonInvitation}", UriKind.Relative),
            new { displayName = "Lecteur", status = "Going" });

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);
        var membre = await adhesion.Content.ReadFromJsonAsync<JsonDocument>();

        return (client, membre!.RootElement.GetProperty("memberId").GetGuid());
    }


    private static string Chemin(Guid evenement) => $"/v1/events/{evenement}/messages";

    private static async Task<JsonElement> Fil(
        HttpClient client,
        Guid evenement,
        string requete = "")
    {
        var reponse = await client.GetAsync(new Uri(Chemin(evenement) + requete, UriKind.Relative));
        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement;
    }

    private static async Task<Guid> Envoyer(HttpClient client, Guid evenement, string texte)
    {
        var reponse = await client.PostAsJsonAsync(Chemin(evenement), new { body = texte });
        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.GetProperty("id").GetGuid();
    }

    private async Task<(HttpClient client, Guid evenement, Guid moi)> EvenementAsync()
    {
        var adresse = $"fil-{Guid.NewGuid():N}@partyplan.test";

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
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        var creation = await client.PostAsJsonAsync(
            new Uri("/v1/events", UriKind.Relative),
            new
            {
                name = "Soirée pagination",
                startsAt = DateTimeOffset.UtcNow.AddDays(7),
                timezone = "Europe/Paris",
            });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);
        var evenement = await creation.Content.ReadFromJsonAsync<JsonDocument>();
        var id = evenement!.RootElement.GetProperty("id").GetGuid();

        var membres = await client.GetFromJsonAsync<JsonDocument>(
            new Uri($"/v1/events/{id}/members", UriKind.Relative));
        var moi = membres!.RootElement[0].GetProperty("id").GetGuid();

        return (client, id, moi);
    }
}
