namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Chaîne financière de bout en bout : courses, dépenses, soldes, remboursements.
/// <para>
/// Le jeu de référence du §6.5 est rejoué ici contre la vraie base et les vrais
/// endpoints, en complément du test unitaire : une répartition juste en mémoire mais
/// mal persistée donnerait des soldes faux sans qu'aucun test unitaire ne le voie.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class ChaineFinanciereTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Le_jeu_de_reference_produit_les_soldes_et_les_reglements_attendus()
    {
        var (organisateur, eventId, membres) = await TroisMembresAsync();

        // Les identifiants de membre déterminent l'attribution du reliquat : le tri est
        // celui de la répartition, pas celui de l'adhésion.
        var ordonnes = membres.OrderBy(m => m.Key).ToList();
        var premier = ordonnes[0];
        var second = ordonnes[1];
        var troisieme = ordonnes[2];

        await CreerDepenseAsync(organisateur, eventId, "Courses", 100.00m, premier.Key);
        await CreerDepenseAsync(organisateur, eventId, "Bières", 50.00m, second.Key);
        await CreerDepenseAsync(organisateur, eventId, "Viande", 34.00m, troisieme.Key);

        var page = await LireReglementsAsync(organisateur, eventId);

        page.GetProperty("invariantHolds").GetBoolean().ShouldBeTrue();

        var soldes = page.GetProperty("balances").EnumerateArray()
            .ToDictionary(b => b.GetProperty("memberId").GetGuid(), b => b.GetProperty("amount").GetDecimal());

        // Répartition dépense par dépense : 38,65 / −11,33 / −27,32 (§6.5 corrigé).
        soldes[premier.Key].ShouldBe(38.65m);
        soldes[second.Key].ShouldBe(-11.33m);
        soldes[troisieme.Key].ShouldBe(-27.32m);
        soldes.Values.Sum().ShouldBe(0m);

        var proposes = page.GetProperty("proposed").EnumerateArray().ToList();

        // RG-CALC-01 : la dette la plus forte d'abord, dans l'ordre d'émission.
        proposes.Count.ShouldBe(2);
        proposes[0].GetProperty("fromMemberId").GetGuid().ShouldBe(troisieme.Key);
        proposes[0].GetProperty("toMemberId").GetGuid().ShouldBe(premier.Key);
        proposes[0].GetProperty("amount").GetDecimal().ShouldBe(27.32m);
        proposes[1].GetProperty("fromMemberId").GetGuid().ShouldBe(second.Key);
        proposes[1].GetProperty("amount").GetDecimal().ShouldBe(11.33m);
    }

    [Fact]
    public async Task RG_RMB_03_un_remboursement_marque_disparait_des_propositions()
    {
        var (organisateur, eventId, membres) = await TroisMembresAsync();
        var ordonnes = membres.OrderBy(m => m.Key).ToList();

        await CreerDepenseAsync(organisateur, eventId, "Courses", 90.00m, ordonnes[0].Key);

        var avant = await LireReglementsAsync(organisateur, eventId);
        avant.GetProperty("proposed").GetArrayLength().ShouldBe(2);

        var premier = avant.GetProperty("proposed")[0];

        var marquage = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/settlements",
            new
            {
                fromMemberId = premier.GetProperty("fromMemberId").GetGuid(),
                toMemberId = premier.GetProperty("toMemberId").GetGuid(),
                amount = premier.GetProperty("amount").GetDecimal(),
            });

        marquage.StatusCode.ShouldBe(HttpStatusCode.OK);

        var apres = await LireReglementsAsync(organisateur, eventId);

        // Sans prise en compte des règlements effectués, la dette réapparaîtrait
        // indéfiniment et l'utilisateur paierait deux fois.
        apres.GetProperty("proposed").GetArrayLength().ShouldBe(1);
        apres.GetProperty("done").GetArrayLength().ShouldBe(1);
        apres.GetProperty("invariantHolds").GetBoolean().ShouldBeTrue();
    }

    [Fact]
    public async Task EF_RMB_04_l_annulation_d_un_marquage_retablit_la_dette()
    {
        var (organisateur, eventId, membres) = await TroisMembresAsync();
        var ordonnes = membres.OrderBy(m => m.Key).ToList();

        await CreerDepenseAsync(organisateur, eventId, "Courses", 90.00m, ordonnes[0].Key);

        var page = await LireReglementsAsync(organisateur, eventId);
        var premier = page.GetProperty("proposed")[0];

        var marquage = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/settlements",
            new
            {
                fromMemberId = premier.GetProperty("fromMemberId").GetGuid(),
                toMemberId = premier.GetProperty("toMemberId").GetGuid(),
                amount = premier.GetProperty("amount").GetDecimal(),
            });

        var reglementId = (await marquage.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("done")[0].GetProperty("id").GetGuid();

        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{eventId}/settlements/{reglementId}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        var apres = await LireReglementsAsync(organisateur, eventId);
        apres.GetProperty("proposed").GetArrayLength().ShouldBe(2);
        apres.GetProperty("done").GetArrayLength().ShouldBe(0);
    }

    [Fact]
    public async Task RG_DEP_03_le_payeur_peut_etre_exclu_de_l_assiette()
    {
        var (organisateur, eventId, membres) = await TroisMembresAsync();
        var ordonnes = membres.OrderBy(m => m.Key).ToList();
        var payeur = ordonnes[0].Key;

        // Une tournée : le payeur ne participe pas au partage.
        var creation = await PosterAsync(organisateur, $"/v1/events/{eventId}/expenses", new
        {
            label = "Tournée générale",
            amount = 30.00m,
            paidByMemberId = payeur,
            mode = "Selection",
            shares = new[]
            {
                new { memberId = ordonnes[1].Key, share = 1 },
                new { memberId = ordonnes[2].Key, share = 1 },
            },
        });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var detail = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        detail.GetProperty("shares").GetArrayLength().ShouldBe(2);
        detail.GetProperty("shares").EnumerateArray()
            .ShouldNotContain(s => s.GetProperty("memberId").GetGuid() == payeur);

        var page = await LireReglementsAsync(organisateur, eventId);
        var soldes = page.GetProperty("balances").EnumerateArray()
            .ToDictionary(b => b.GetProperty("memberId").GetGuid(), b => b.GetProperty("amount").GetDecimal());

        soldes[payeur].ShouldBe(30.00m);
        soldes[ordonnes[1].Key].ShouldBe(-15.00m);
        soldes[ordonnes[2].Key].ShouldBe(-15.00m);
    }

    [Fact]
    public async Task RG_DEP_01_un_montant_hors_bornes_est_refuse()
    {
        var (organisateur, eventId, _) = await TroisMembresAsync();

        foreach (var montant in new[] { 0m, -5m, 100_000m })
        {
            var reponse = await PosterAsync(organisateur, $"/v1/events/{eventId}/expenses", new
            {
                label = "Hors bornes",
                amount = montant,
            });

            reponse.StatusCode.ShouldBe(HttpStatusCode.BadRequest, $"montant {montant}");
        }
    }

    [Fact]
    public async Task RG_DEP_05_une_depense_supprimee_sort_des_soldes_mais_pas_de_la_base()
    {
        var (organisateur, eventId, membres) = await TroisMembresAsync();
        var payeur = membres.OrderBy(m => m.Key).First().Key;

        var creation = await CreerDepenseAsync(organisateur, eventId, "À annuler", 60.00m, payeur);
        var depenseId = creation.GetProperty("id").GetGuid();

        (await LireReglementsAsync(organisateur, eventId))
            .GetProperty("proposed").GetArrayLength().ShouldBeGreaterThan(0);

        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{eventId}/expenses/{depenseId}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        var apres = await LireReglementsAsync(organisateur, eventId);
        apres.GetProperty("proposed").GetArrayLength().ShouldBe(0);
        apres.GetProperty("invariantHolds").GetBoolean().ShouldBeTrue();

        // La dépense n'apparaît plus dans la liste : l'effacement est logique, la trace
        // subsiste en base pour expliquer un solde passé.
        var liste = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/expenses");
        liste!.RootElement.GetProperty("items").EnumerateArray()
            .ShouldNotContain(e => e.GetProperty("id").GetGuid() == depenseId);
    }

    [Fact]
    public async Task EF_CRS_07_la_saisie_d_un_prix_paye_engendre_une_depense()
    {
        var (organisateur, eventId, membres) = await TroisMembresAsync();

        var ajout = await PosterAsync(organisateur, $"/v1/events/{eventId}/shopping", new
        {
            name = "Bières",
            quantity = 12m,
            unit = "bouteilles",
            category = "Drinks",
            estimatedPrice = 20.00m,
        });

        ajout.StatusCode.ShouldBe(HttpStatusCode.OK);
        var itemId = (await ajout.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        // RG-CRS-03 : le prix estimé n'entre dans aucun calcul.
        (await LireReglementsAsync(organisateur, eventId))
            .GetProperty("proposed").GetArrayLength().ShouldBe(0);

        var achat = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping/{itemId}/purchase",
            new { purchasedQuantity = 12m, actualPrice = 24.00m });

        achat.StatusCode.ShouldBe(HttpStatusCode.OK);

        var depenses = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/expenses");

        depenses!.RootElement.GetProperty("total").GetDecimal().ShouldBe(24.00m);
        depenses.RootElement.GetProperty("items").EnumerateArray()
            .ShouldContain(e => e.GetProperty("fromShoppingItem").GetBoolean());

        // Ressaisir le prix ne doit pas créer une seconde dépense.
        await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping/{itemId}/purchase",
            new { purchasedQuantity = 12m, actualPrice = 26.00m });

        var apres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/expenses");
        apres!.RootElement.GetProperty("items").GetArrayLength().ShouldBe(1);
        apres.RootElement.GetProperty("total").GetDecimal().ShouldBe(26.00m);
    }

    [Fact]
    public async Task EF_CRS_08_un_article_portant_une_depense_ne_se_supprime_pas()
    {
        var (organisateur, eventId, _) = await TroisMembresAsync();

        var ajout = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping",
            new { name = "Charbon", category = "Supplies" });

        var itemId = (await ajout.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping/{itemId}/purchase",
            new { actualPrice = 12.50m });

        var refus = await organisateur.DeleteAsync(
            new Uri($"/v1/events/{eventId}/shopping/{itemId}", UriKind.Relative));

        refus.StatusCode.ShouldBe(HttpStatusCode.UnprocessableEntity);
        (await Code(refus)).ShouldBe("shopping.has_expense");
    }

    [Fact]
    public async Task RG_CRS_01_deux_attributions_simultanees_ne_laissent_qu_un_gagnant()
    {
        var (organisateur, eventId, _) = await TroisMembresAsync();
        var (autre, _) = await RejoindreAvecCompteAsync(eventId, organisateur, "Concurrent");

        var ajout = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping",
            new { name = "Glace", category = "Food" });

        var itemId = (await ajout.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        // Deux appels lancés ensemble : c'est le cas normal d'une liste partagée, pas un
        // cas limite. Le contrôle est en base, jamais dans l'interface.
        var chemin = new Uri($"/v1/events/{eventId}/shopping/{itemId}/claim", UriKind.Relative);
        var course = await Task.WhenAll(
            organisateur.PostAsync(chemin, null),
            autre.PostAsync(chemin, null));

        course.Count(r => r.StatusCode == HttpStatusCode.OK).ShouldBe(1);
        course.Count(r => r.StatusCode == HttpStatusCode.Conflict).ShouldBe(1);

        var liste = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/shopping");
        liste!.RootElement.GetProperty("progress").GetProperty("claimed").GetInt32().ShouldBe(1);
    }

    [Fact]
    public async Task RG_CRS_02_un_achat_partiel_laisse_un_reliquat()
    {
        var (organisateur, eventId, _) = await TroisMembresAsync();

        var ajout = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping",
            new { name = "Bouteilles", quantity = 12m, category = "Drinks" });

        var itemId = (await ajout.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        var achat = await PosterAsync(
            organisateur,
            $"/v1/events/{eventId}/shopping/{itemId}/purchase",
            new { purchasedQuantity = 8m, actualPrice = 16.00m });

        var vue = (await achat.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;
        vue.GetProperty("remainingQuantity").GetDecimal().ShouldBe(4m);
    }

    [Fact]
    public async Task RG_SEC_02_un_non_membre_ne_voit_ni_depenses_ni_soldes()
    {
        var (_, eventId, _) = await TroisMembresAsync();
        var etranger = await CompteAsync("Etranger");

        foreach (var chemin in new[] { "expenses", "shopping", "settlements" })
        {
            (await etranger.GetAsync(new Uri($"/v1/events/{eventId}/{chemin}", UriKind.Relative)))
                .StatusCode.ShouldBe(HttpStatusCode.NotFound, chemin);
        }
    }

    // ------------------------------------------------------------------ aides ----

    private async Task<(HttpClient Organisateur, Guid EventId, Dictionary<Guid, string> Membres)>
        TroisMembresAsync()
    {
        var organisateur = await CompteAsync("Maxence");
        var creation = await EvenementsTests.CreerBrutAsync(organisateur, new
        {
            name = "Chaîne financière",
            startsAt = DateTimeOffset.UtcNow.AddDays(3),
        });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);
        var eventId = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        await RejoindreAvecCompteAsync(eventId, organisateur, "Lucas");
        await RejoindreAvecCompteAsync(eventId, organisateur, "Emma");

        var membres = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        return (
            organisateur,
            eventId,
            membres!.RootElement.EnumerateArray().ToDictionary(
                m => m.GetProperty("id").GetGuid(),
                m => m.GetProperty("displayName").GetString()!));
    }

    private async Task<(HttpClient Client, Guid MemberId)> RejoindreAvecCompteAsync(
        Guid eventId,
        HttpClient organisateur,
        string nom)
    {
        var invitation = await organisateur.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/invitation");

        var client = await CompteAsync(nom);

        var adhesion = await EvenementsTests.RejoindreBrutAsync(
            client,
            $"/v1/join/{invitation!.RootElement.GetProperty("token").GetString()!}",
            Guid.CreateVersion7().ToString());

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        (await client.PatchAsJsonAsync(
                $"/v1/events/{eventId}/members/me",
                new { status = "Going" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        return (
            client,
            (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("memberId").GetGuid());
    }

    private static async Task<JsonElement> CreerDepenseAsync(
        HttpClient client,
        Guid eventId,
        string libelle,
        decimal montant,
        Guid payeur)
    {
        var reponse = await PosterAsync(client, $"/v1/events/{eventId}/expenses", new
        {
            label = libelle,
            amount = montant,
            paidByMemberId = payeur,
        });

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK, libelle);

        return (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement.Clone();
    }

    private static async Task<JsonElement> LireReglementsAsync(HttpClient client, Guid eventId)
    {
        var page = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/settlements");

        return page!.RootElement.Clone();
    }

    /// <summary>Les écritures financières exigent une clé d'idempotence (§8.1).</summary>
    private static Task<HttpResponseMessage> PosterAsync(
        HttpClient client,
        string chemin,
        object corps)
    {
        var requete = new HttpRequestMessage(HttpMethod.Post, new Uri(chemin, UriKind.Relative))
        {
            Content = JsonContent.Create(corps),
        };

        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        return client.SendAsync(requete);
    }

    private async Task<HttpClient> CompteAsync(string nom)
    {
        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = $"fin-{Guid.CreateVersion7():N}@partyplan.test",
            password = MotDePasse,
            displayName = nom,
        });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("accessToken").GetString());

        return client;
    }

    private static async Task<string?> Code(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }
}
