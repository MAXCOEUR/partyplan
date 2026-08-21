namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Sondages d'un événement (EF-SDG-01 à EF-SDG-04).
/// <para>
/// Ils naissent dans la discussion — c'est là qu'on se demande quoi faire — et se
/// retrouvent dans un écran à eux : un sondage remonté par cinquante messages devient
/// introuvable.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class SondagesTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    private static readonly string[] TroisPlats = ["Pizza", "Sushi", "Burgers"];

    private static readonly string[] DeuxPlats = ["Pizza", "Sushi"];

    private static readonly string[] UneSeuleReponse = ["Oui"];

    private static readonly string[] OuiNon = ["Oui", "Non"];

    private static readonly string[] TroisApports = ["Entrée", "Plat", "Dessert"];

    [Fact]
    public async Task Un_sondage_cree_apparait_dans_la_liste()
    {
        var (client, evenement) = await EvenementAsync();

        var creation = await client.PostAsJsonAsync(
            Chemin(evenement),
            new
            {
                question = "On commande quoi ?",
                options = TroisPlats,
            });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var liste = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var sondages = liste!.RootElement.GetProperty("items");

        sondages.GetArrayLength().ShouldBe(1);
        sondages[0].GetProperty("question").GetString().ShouldBe("On commande quoi ?");
        sondages[0].GetProperty("options").GetArrayLength().ShouldBe(3);
        sondages[0].GetProperty("closed").GetBoolean().ShouldBeFalse();
    }

    [Fact]
    public async Task Un_sondage_est_porte_par_un_message_du_fil()
    {
        // C'est dans la conversation qu'on se demande quoi faire : un sondage créé
        // ailleurs passerait inaperçu.
        var (client, evenement) = await EvenementAsync();

        var creation = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { question = "On commande quoi ?", options = DeuxPlats });

        var sondage = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        var fil = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/messages");

        var messages = fil!.RootElement.GetProperty("items");

        messages.GetArrayLength().ShouldBe(1);
        messages[0].GetProperty("pollId").GetGuid().ShouldBe(sondage);
    }

    [Fact]
    public async Task Un_sondage_sans_deux_options_est_refuse()
    {
        // Une seule réponse n'est pas un choix.
        var (client, evenement) = await EvenementAsync();

        var refus = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { question = "On y va ?", options = UneSeuleReponse });

        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(refus)).ShouldBe("poll.options_required");
    }

    [Fact]
    public async Task Une_question_vide_est_refusee()
    {
        var (client, evenement) = await EvenementAsync();

        var refus = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { question = "  ", options = OuiNon });

        refus.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await Code(refus)).ShouldBe("poll.question_required");
    }

    [Fact]
    public async Task Voter_compte_la_voix_et_marque_son_choix()
    {
        var (client, evenement) = await EvenementAsync();
        var (sondage, options) = await Creer(client, evenement);

        var vote = await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[0] } });

        vote.StatusCode.ShouldBe(HttpStatusCode.OK);

        var liste = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var premier = liste!.RootElement.GetProperty("items")[0];
        var choix = premier.GetProperty("options")[0];

        choix.GetProperty("votes").GetInt32().ShouldBe(1);
        choix.GetProperty("mine").GetBoolean().ShouldBeTrue();
        premier.GetProperty("iVoted").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task Changer_de_vote_remplace_le_precedent()
    {
        // On change d'avis : deux voix d'une même personne fausseraient le résultat.
        var (client, evenement) = await EvenementAsync();
        var (sondage, options) = await Creer(client, evenement);

        await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[0] } });

        await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[1] } });

        var liste = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var choix = liste!.RootElement.GetProperty("items")[0].GetProperty("options");

        choix[0].GetProperty("votes").GetInt32().ShouldBe(0);
        choix[1].GetProperty("votes").GetInt32().ShouldBe(1);
    }

    [Fact]
    public async Task Un_vote_multiple_est_refuse_sur_un_sondage_a_choix_unique()
    {
        var (client, evenement) = await EvenementAsync();
        var (sondage, options) = await Creer(client, evenement);

        var refus = await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[0], options[1] } });

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("poll.single_choice");
    }

    [Fact]
    public async Task Un_sondage_a_choix_multiple_accepte_plusieurs_voix()
    {
        // « Qui apporte quoi » demande de cocher plusieurs cases : l'index de la table
        // l'interdisait, ce qui rendait l'option annoncée inopérante.
        var (client, evenement) = await EvenementAsync();

        var creation = await client.PostAsJsonAsync(
            Chemin(evenement),
            new
            {
                question = "Tu apportes quoi ?",
                options = TroisApports,
                allowMultiple = true,
            });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);
        var corps = await creation.Content.ReadFromJsonAsync<JsonDocument>();
        var sondage = corps!.RootElement.GetProperty("id").GetGuid();

        var options = corps.RootElement.GetProperty("options")
            .EnumerateArray()
            .Select(o => o.GetProperty("id").GetGuid())
            .ToArray();

        var vote = await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[0], options[2] } });

        vote.StatusCode.ShouldBe(HttpStatusCode.OK);

        var liste = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var choix = liste!.RootElement.GetProperty("items")[0].GetProperty("options");

        choix[0].GetProperty("votes").GetInt32().ShouldBe(1);
        choix[1].GetProperty("votes").GetInt32().ShouldBe(0);
        choix[2].GetProperty("votes").GetInt32().ShouldBe(1);
    }

    [Fact]
    public async Task Retirer_tous_ses_choix_annule_son_vote()
    {
        var (client, evenement) = await EvenementAsync();
        var (sondage, options) = await Creer(client, evenement);

        await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[0] } });

        await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = Array.Empty<Guid>() });

        var liste = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var premier = liste!.RootElement.GetProperty("items")[0];

        premier.GetProperty("iVoted").GetBoolean().ShouldBeFalse();
        premier.GetProperty("options")[0].GetProperty("votes").GetInt32().ShouldBe(0);
    }

    [Fact]
    public async Task Un_sondage_clos_n_accepte_plus_de_vote()
    {
        var (client, evenement) = await EvenementAsync();
        var (sondage, options) = await Creer(client, evenement);

        (await client.PostAsync(
                new Uri($"{Chemin(evenement)}/{sondage}/close", UriKind.Relative),
                null))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var refus = await client.PutAsJsonAsync(
            new Uri($"{Chemin(evenement)}/{sondage}/votes", UriKind.Relative),
            new { optionIds = new[] { options[0] } });

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("poll.closed");
    }

    [Fact]
    public async Task Les_sondages_ouverts_viennent_avant_les_clos()
    {
        // On ouvre cet écran pour répondre, pas pour relire ce qui est tranché.
        var (client, evenement) = await EvenementAsync();

        var (ancien, _) = await Creer(client, evenement, "Ancien");
        await Creer(client, evenement, "Récent");

        (await client.PostAsync(
                new Uri($"{Chemin(evenement)}/{ancien}/close", UriKind.Relative),
                null))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var liste = await client.GetFromJsonAsync<JsonDocument>(Chemin(evenement));
        var items = liste!.RootElement.GetProperty("items");

        items[0].GetProperty("question").GetString().ShouldBe("Récent");
        items[0].GetProperty("closed").GetBoolean().ShouldBeFalse();
        items[1].GetProperty("closed").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task Un_non_membre_ne_voit_pas_les_sondages()
    {
        var (_, evenement) = await EvenementAsync();
        var (etranger, _) = await EvenementAsync();

        var refus = await etranger.GetAsync(new Uri(Chemin(evenement), UriKind.Relative));

        refus.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    // ------------------------------------------------------------------ aides ----

    private static string Chemin(Guid evenement) => $"/v1/events/{evenement}/polls";

    private static async Task<(Guid sondage, Guid[] options)> Creer(
        HttpClient client,
        Guid evenement,
        string question = "On commande quoi ?")
    {
        var creation = await client.PostAsJsonAsync(
            Chemin(evenement),
            new { question, options = DeuxPlats });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await creation.Content.ReadFromJsonAsync<JsonDocument>();

        return (
            corps!.RootElement.GetProperty("id").GetGuid(),
            [
                .. corps.RootElement.GetProperty("options")
                    .EnumerateArray()
                    .Select(o => o.GetProperty("id").GetGuid()),
            ]);
    }

    private async Task<(HttpClient client, Guid evenement)> EvenementAsync()
    {
        var adresse = $"sondage-{Guid.NewGuid():N}@partyplan.test";

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
            new { name = "Crémaillère", startsAt = DateTimeOffset.UtcNow.AddDays(10) });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);
        var evenement = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        client.DefaultRequestHeaders.Remove("Idempotency-Key");

        return (client, evenement);
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.TryGetProperty("code", out var code)
            ? code.GetString()
            : null;
    }
}
