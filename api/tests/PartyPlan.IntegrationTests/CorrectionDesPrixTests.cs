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
/// Correction des montants après coup : dépenses saisies à la main, et prix payé d'un
/// article de courses.
/// <para>
/// Une somme se saisit vite et se trompe souvent. Ce qui compte est donc de pouvoir la
/// corriger — mais seulement celle qu'on a soi-même avancée, sauf pour une personne qui
/// gère l'événement : elle arbitre les comptes de la soirée.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class CorrectionDesPrixTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Le_payeur_corrige_le_montant_de_sa_depense()
    {
        var (client, evenement, _) = await EvenementAsync();
        var depense = await CreerDepense(client, evenement, "Taxi", 24m);

        var correction = await client.PatchAsJsonAsync(
            new Uri($"/v1/events/{evenement}/expenses/{depense}", UriKind.Relative),
            new { label = "Taxi", amount = 31.50m, mode = "AllPresent" });

        correction.StatusCode.ShouldBe(HttpStatusCode.OK);

        var apres = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/expenses/{depense}");

        apres!.RootElement.GetProperty("amount").GetDecimal().ShouldBe(31.50m);
        // RG-DEP-04 : l'état précédent est conservé. Un montant qui change sans trace
        // rend un litige insoluble.
        apres.RootElement.GetProperty("revisionCount").GetInt32().ShouldBe(1);
    }

    [Fact]
    public async Task Le_payeur_supprime_sa_depense()
    {
        var (client, evenement, _) = await EvenementAsync();
        var depense = await CreerDepense(client, evenement, "Erreur de saisie", 12m);

        (await client.DeleteAsync(
                new Uri($"/v1/events/{evenement}/expenses/{depense}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var liste = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/expenses");

        liste!.RootElement.GetProperty("items").GetArrayLength().ShouldBe(0);
    }

    [Fact]
    public async Task Un_membre_ne_touche_pas_a_la_depense_d_un_autre()
    {
        // Corriger la dépense d'autrui change ce qu'il a avancé, donc ce que chacun lui
        // doit. C'est le geste qui rend les comptes contestables.
        var (organisateur, evenement, _) = await EvenementAsync();
        var invite = await MembreAsync(organisateur, evenement, "Lucas");

        var depense = await CreerDepense(organisateur, evenement, "Taxi", 24m);

        var refus = await invite.PatchAsJsonAsync(
            new Uri($"/v1/events/{evenement}/expenses/{depense}", UriKind.Relative),
            new { label = "Taxi", amount = 3m, mode = "AllPresent" });

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("expense.not_mine");
    }

    [Fact]
    public async Task Un_membre_ne_supprime_pas_la_depense_d_un_autre()
    {
        var (organisateur, evenement, _) = await EvenementAsync();
        var invite = await MembreAsync(organisateur, evenement, "Lucas");

        var depense = await CreerDepense(organisateur, evenement, "Taxi", 24m);

        var refus = await invite.DeleteAsync(
            new Uri($"/v1/events/{evenement}/expenses/{depense}", UriKind.Relative));

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("expense.not_mine");
    }

    [Fact]
    public async Task L_organisateur_corrige_la_depense_de_n_importe_qui()
    {
        // Il arbitre les comptes de la soirée : sans lui, une erreur de saisie d'un
        // invité parti depuis resterait inscrite pour toujours.
        var (organisateur, evenement, _) = await EvenementAsync();
        var invite = await MembreAsync(organisateur, evenement, "Lucas");

        var depense = await CreerDepense(invite, evenement, "Glaçons", 8m);

        var correction = await organisateur.PatchAsJsonAsync(
            new Uri($"/v1/events/{evenement}/expenses/{depense}", UriKind.Relative),
            new { label = "Glaçons", amount = 5m, mode = "AllPresent" });

        correction.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Le_prix_paye_d_un_article_se_corrige_apres_coup()
    {
        // Le ticket ne correspond jamais tout à fait à ce qu'on avait annoncé.
        var (client, evenement, _) = await EvenementAsync();
        var article = await CreerArticle(client, evenement, "Bières");

        await Acheter(client, evenement, article, 28.40m);

        var apres = await Acheter(client, evenement, article, 31.10m);
        apres.StatusCode.ShouldBe(HttpStatusCode.OK);

        var depenses = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/expenses");

        // Une seule dépense, au nouveau montant : la correction remplace, elle
        // n'ajoute pas.
        depenses!.RootElement.GetProperty("items").GetArrayLength().ShouldBe(1);
        depenses.RootElement.GetProperty("items")[0]
            .GetProperty("amount").GetDecimal().ShouldBe(31.10m);
    }

    [Fact]
    public async Task Retirer_le_prix_d_un_article_efface_sa_depense()
    {
        var (client, evenement, _) = await EvenementAsync();
        var article = await CreerArticle(client, evenement, "Bières");

        await Acheter(client, evenement, article, 28.40m);
        await Acheter(client, evenement, article, null);

        var depenses = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/expenses");

        depenses!.RootElement.GetProperty("items").GetArrayLength().ShouldBe(0);
    }

    [Fact]
    public async Task Un_membre_ne_declare_pas_l_achat_d_un_article_pris_par_un_autre()
    {
        // Déclarer l'achat d'autrui créerait une dépense à son nom, donc une créance
        // qu'il n'a jamais avancée.
        var (organisateur, evenement, _) = await EvenementAsync();
        var invite = await MembreAsync(organisateur, evenement, "Lucas");

        var article = await CreerArticle(organisateur, evenement, "Bières");

        (await organisateur.PostAsJsonAsync(
                new Uri($"/v1/events/{evenement}/shopping/{article}/claim", UriKind.Relative),
                new { }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var refus = await Acheter(invite, evenement, article, 28.40m);

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("shopping.not_claimed_by_me");
    }

    [Fact]
    public async Task L_organisateur_declare_l_achat_a_la_place_de_quiconque()
    {
        var (organisateur, evenement, _) = await EvenementAsync();
        var invite = await MembreAsync(organisateur, evenement, "Lucas");

        var article = await CreerArticle(organisateur, evenement, "Bières");

        (await invite.PostAsJsonAsync(
                new Uri($"/v1/events/{evenement}/shopping/{article}/claim", UriKind.Relative),
                new { }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var achat = await Acheter(organisateur, evenement, article, 28.40m);

        achat.StatusCode.ShouldBe(HttpStatusCode.OK);

        // La dépense reste au nom de celui qui s'en occupait, pas de l'organisateur qui
        // a saisi : c'est l'invité qui a avancé l'argent.
        var depenses = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/expenses");

        depenses!.RootElement.GetProperty("items")[0]
            .GetProperty("paidByDisplayName").GetString().ShouldBe("Lucas");
    }

    [Fact]
    public async Task Un_article_libre_s_achete_par_qui_le_declare()
    {
        // Personne ne s'était attribué l'article : celui qui déclare l'achat le prend
        // du même coup.
        var (client, evenement, _) = await EvenementAsync();
        var article = await CreerArticle(client, evenement, "Glace");

        (await Acheter(client, evenement, article, 4.20m))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    // ------------------------------------------------------------------ aides ----

    private static async Task<HttpResponseMessage> Acheter(
        HttpClient client,
        Guid evenement,
        Guid article,
        decimal? prix)
    {
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        return await client.PostAsJsonAsync(
            new Uri(
                $"/v1/events/{evenement}/shopping/{article}/purchase",
                UriKind.Relative),
            new { actualPrice = prix });
    }

    private static async Task<Guid> CreerArticle(
        HttpClient client,
        Guid evenement,
        string nom)
    {
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        var reponse = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{evenement}/shopping", UriKind.Relative),
            new { name = nom, category = "Drinks" });

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.GetProperty("id").GetGuid();
    }

    private static async Task<Guid> CreerDepense(
        HttpClient client,
        Guid evenement,
        string libelle,
        decimal montant)
    {
        client.DefaultRequestHeaders.Remove("Idempotency-Key");
        client.DefaultRequestHeaders.Add("Idempotency-Key", Guid.NewGuid().ToString());

        var reponse = await client.PostAsJsonAsync(
            new Uri($"/v1/events/{evenement}/expenses", UriKind.Relative),
            new { label = libelle, amount = montant, mode = "AllPresent" });

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);

        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.GetProperty("id").GetGuid();
    }

    /// <summary>Compte neuf, événement neuf, identifiant de membre de l'appelant.</summary>
    private async Task<(HttpClient client, Guid evenement, Guid moi)> EvenementAsync()
    {
        var adresse = $"prix-{Guid.NewGuid():N}@partyplan.test";

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

        var moi = Guid.Empty;
        await fixture.WithDatabaseAsync(async db =>
        {
            moi = await db.EventMembers
                .IgnoreQueryFilters()
                .Where(m => m.EventId == evenement)
                .Select(m => m.Id)
                .SingleAsync();
        });

        return (client, evenement, moi);
    }

    /// <summary>Second compte, entré par le lien d'invitation.</summary>
    private async Task<HttpClient> MembreAsync(
        HttpClient organisateur,
        Guid evenement,
        string prenom)
    {
        var invitation = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{evenement}/invitation");

        var jeton = invitation!.RootElement.GetProperty("token").GetString();

        using var anonyme = fixture.CreateClient();
        var inscription = await anonyme.PostAsJsonAsync(
            "/v1/auth/register",
            new
            {
                email = $"prix-{Guid.NewGuid():N}@partyplan.test",
                password = MotDePasse,
                displayName = prenom,
            });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("accessToken").GetString());

        var adhesion = await EvenementsTests.RejoindreBrutAsync(
            client,
            $"/v1/join/{jeton}",
            Guid.CreateVersion7().ToString());

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        (await client.PatchAsJsonAsync(
                $"/v1/events/{evenement}/members/me",
                new { status = "Going" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        return client;
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();
        return corps!.RootElement.TryGetProperty("code", out var code)
            ? code.GetString()
            : null;
    }
}
