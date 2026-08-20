namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// EF-AUTH-11 — conversion d'une participation d'invité en compte permanent.
/// <para>
/// La liaison se fait sur l'empreinte du jeton d'invité présent sur l'appareil, jamais
/// sur le prénom (RG-AUTH-07). Deux membres homonymes ne doivent jamais fusionner :
/// une fusion ferait disparaître une participante et, plus tard, ses dépenses.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class ConversionInviteTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Inscription_avec_jeton_invite_rattache_la_participation()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton) = await CreerAsync(organisateur, "Conversion");
        var jetonInvite = await RejoindreCommeInviteAsync(jeton, "Léa");

        var session = await InscrireAsync(jetonInvite);

        var evenements = await session.GetFromJsonAsync<JsonDocument>("/v1/events");

        evenements!.RootElement.EnumerateArray()
            .ShouldContain(e => e.GetProperty("id").GetString() == eventId);
    }

    [Fact]
    public async Task Aucun_doublon_de_membre_apres_conversion()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton) = await CreerAsync(organisateur, "Sans doublon");
        var jetonInvite = await RejoindreCommeInviteAsync(jeton, "Léa");

        await InscrireAsync(jetonInvite);

        var membres = await MembresAsync(organisateur, eventId);

        membres.EnumerateArray()
            .Count(m => m.GetProperty("displayName").GetString() == "Léa")
            .ShouldBe(1);
    }

    [Fact]
    public async Task Deux_homonymes_ne_fusionnent_pas()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton) = await CreerAsync(organisateur, "Homonymes");
        var jetonA = await RejoindreCommeInviteAsync(jeton, "Léa");
        var jetonB = await RejoindreCommeInviteAsync(jeton, "Léa");

        var sessionA = await InscrireAsync(jetonA);
        var sessionB = await InscrireAsync(jetonB);

        var membres = await MembresAsync(organisateur, eventId);

        var leas = membres.EnumerateArray()
            .Where(m => m.GetProperty("displayName").GetString() == "Léa")
            .ToList();

        // Deux personnes, deux lignes. Fusionner sur le prénom ferait disparaître une
        // participante et, plus tard, ses dépenses.
        leas.Count.ShouldBe(2);
        leas.ShouldAllBe(m => m.GetProperty("hasAccount").GetBoolean());

        // Chaque compte ne se reconnaît que dans sa propre ligne. L'identifiant de
        // compte n'est volontairement pas exposé — le révéler à tous les participants,
        // invités compris, serait une fuite — mais `isMe` suffit à prouver que les deux
        // lignes appartiennent à deux comptes distincts.
        var vueA = await MembresAsync(sessionA, eventId);
        var vueB = await MembresAsync(sessionB, eventId);

        var moiA = vueA.EnumerateArray().Single(m => m.GetProperty("isMe").GetBoolean());
        var moiB = vueB.EnumerateArray().Single(m => m.GetProperty("isMe").GetBoolean());

        moiA.GetProperty("displayName").GetString().ShouldBe("Léa");
        moiB.GetProperty("displayName").GetString().ShouldBe("Léa");
        moiA.GetProperty("id").GetString().ShouldNotBe(moiB.GetProperty("id").GetString());
    }

    [Fact]
    public async Task Jeton_invite_inconnu_ne_produit_aucune_erreur()
    {
        var session = await InscrireAsync(jetonInvite: null);

        var reponse = await ReclamerAsync(session, "jeton-qui-ne-correspond-a-rien");

        // Un jeton périmé ou déjà consommé n'est pas une erreur : il ne doit pas
        // produire un message d'échec pour une action sans conséquence.
        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("linked").GetInt32().ShouldBe(0);
    }

    [Fact]
    public async Task Le_rattachement_exige_une_session()
    {
        using var anonyme = fixture.CreateClient();

        var reponse = await anonyme.PostAsJsonAsync(
            "/v1/auth/guest-claim",
            new { guestToken = "peu importe" });

        reponse.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Membre_deja_rattache_a_un_compte_n_est_pas_repris()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton) = await CreerAsync(organisateur, "Déjà rattachée");
        var jetonInvite = await RejoindreCommeInviteAsync(jeton, "Léa");

        await InscrireAsync(jetonInvite);

        // Le même jeton, présenté par un second compte : le membre est déjà nominatif.
        // Le laisser reprendre reviendrait à transférer une participation, et avec elle
        // les dépenses qui y seront rattachées.
        var intrus = await InscrireAsync(jetonInvite);

        var membres = await MembresAsync(organisateur, eventId);
        membres.EnumerateArray()
            .Count(m => m.GetProperty("displayName").GetString() == "Léa")
            .ShouldBe(1);

        // L'intrus ne voit pas l'événement : il n'en est pas membre.
        var sesEvenements = await intrus.GetFromJsonAsync<JsonDocument>("/v1/events");
        sesEvenements!.RootElement.EnumerateArray()
            .ShouldNotContain(e => e.GetProperty("id").GetString() == eventId);
    }

    [Fact]
    public async Task Connexion_avec_jeton_invite_rattache_aussi()
    {
        var organisateur = await CompteAsync();
        var (eventId, jeton) = await CreerAsync(organisateur, "Rattachement à la connexion");

        // Le compte existe déjà, créé sur un autre appareil ; c'est en se connectant
        // ici que la personne doit récupérer sa participation.
        var adresse = $"conv-{Guid.CreateVersion7():N}@partyplan.test";
        await InscrireAsync(jetonInvite: null, adresse: adresse);

        var jetonInvite = await RejoindreCommeInviteAsync(jeton, "Léa");

        using var anonyme = fixture.CreateClient();
        var connexion = await anonyme.PostAsJsonAsync("/v1/auth/login", new
        {
            email = adresse,
            password = MotDePasse,
        });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var session = ClientAvecJeton(
            (await connexion.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("accessToken").GetString()!);

        (await ReclamerAsync(session, jetonInvite)).StatusCode.ShouldBe(HttpStatusCode.OK);

        var evenements = await session.GetFromJsonAsync<JsonDocument>("/v1/events");
        evenements!.RootElement.EnumerateArray()
            .ShouldContain(e => e.GetProperty("id").GetString() == eventId);
    }

    // ------------------------------------------------------------------ aides ----

    private HttpClient ClientAvecJeton(string jeton)
    {
        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jeton);

        return client;
    }

    private async Task<HttpClient> CompteAsync()
    {
        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = $"conv-{Guid.CreateVersion7():N}@partyplan.test",
            password = MotDePasse,
            displayName = "Organisateur",
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        return ClientAvecJeton((await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString()!);
    }

    /// <summary>
    /// Crée un compte puis, si un jeton d'invité est fourni, réclame la participation.
    /// <para>
    /// Deux appels et non un : le rattachement passe par un endpoint authentifié, seul
    /// moyen de couvrir les quatre points d'ouverture de session de l'API.
    /// </para>
    /// </summary>
    private async Task<HttpClient> InscrireAsync(string? jetonInvite, string? adresse = null)
    {
        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = adresse ?? $"conv-{Guid.CreateVersion7():N}@partyplan.test",
            password = MotDePasse,
            displayName = "Léa",
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var session = ClientAvecJeton(
            (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("accessToken").GetString()!);

        if (jetonInvite is not null)
        {
            (await ReclamerAsync(session, jetonInvite))
                .StatusCode.ShouldBe(HttpStatusCode.OK);
        }

        return session;
    }

    private static Task<HttpResponseMessage> ReclamerAsync(HttpClient session, string jeton) =>
        session.PostAsJsonAsync("/v1/auth/guest-claim", new { guestToken = jeton });

    private static async Task<(string eventId, string jeton)> CreerAsync(HttpClient client, string nom)
    {
        var creation = await EvenementsTests.CreerBrutAsync(client, new
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

        return (eventId, invitation!.RootElement.GetProperty("token").GetString()!);
    }

    private async Task<string> RejoindreCommeInviteAsync(string jeton, string prenom)
    {
        using var invite = fixture.CreateClient();

        var adhesion = await EvenementsTests.RejoindreBrutAsync(
            invite,
            jeton,
            new { displayName = prenom, status = "Going" },
            Guid.CreateVersion7().ToString());

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        return (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("guestToken").GetString()!;
    }

    private static async Task<JsonElement> MembresAsync(HttpClient client, string eventId)
    {
        var membres = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        return membres!.RootElement.Clone();
    }
}
