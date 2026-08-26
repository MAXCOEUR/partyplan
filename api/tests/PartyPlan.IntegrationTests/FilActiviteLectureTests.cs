namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Lecture du fil (EF-FIL-01, §8.1).
/// <para>
/// Le cloisonnement y est vérifié comme partout ailleurs : un fil qui fuite est pire
/// qu'une liste de courses qui fuite, puisqu'il porte les montants et qui doit quoi.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FilActiviteLectureTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Un_non_membre_recoit_404()
    {
        // RG-SEC-02 : jamais 403, qui confirmerait l'existence de l'événement.
        var (_, eventId) = await SoireeAsync();
        var etranger = await fixture.CompteAsync("Étranger");

        var reponse = await etranger.GetAsync(Chemin(eventId));

        reponse.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Un_administrateur_plateforme_non_membre_recoit_404()
    {
        // Règle 2, RG-ADM-01. Sans elle, la promesse d'événement privé est fausse.
        var (_, eventId) = await SoireeAsync();

        using var administrateur = fixture.CreateClient();
        administrateur.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            TestTokens.ForUser(Guid.CreateVersion7(), PlatformRole.PlatformAdmin));

        var reponse = await administrateur.GetAsync(Chemin(eventId));

        reponse.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Un_appelant_anonyme_recoit_401()
    {
        var (_, eventId) = await SoireeAsync();
        using var anonyme = fixture.CreateClient();

        (await anonyme.GetAsync(Chemin(eventId)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task La_page_descend_du_plus_recent_au_plus_ancien()
    {
        var (client, eventId) = await SoireeAsync();
        await AjouterArticlesAsync(client, eventId, 3);

        var page = await LirePageAsync(client, eventId, limite: 30);

        page.Encore.ShouldBeFalse();
        page.Lignes.Count.ShouldBeGreaterThanOrEqualTo(3);
        page.Lignes[0].Cree.ShouldBeGreaterThanOrEqualTo(page.Lignes[^1].Cree);
        page.Lignes[0].Categorie.ShouldBe(ActivityKinds.ItemCreated);
    }

    [Fact]
    public async Task Le_curseur_ne_recouvre_ni_n_omet_aucune_ligne()
    {
        var (client, eventId) = await SoireeAsync();
        await AjouterArticlesAsync(client, eventId, 11);

        // 12 lignes : l'arrivée de Camille, plus onze articles.
        var premiere = await LirePageAsync(client, eventId, limite: 5);
        var seconde = await LirePageAsync(client, eventId, limite: 5, avant: premiere.Lignes[^1].Id);
        var troisieme = await LirePageAsync(client, eventId, limite: 5, avant: seconde.Lignes[^1].Id);

        premiere.Encore.ShouldBeTrue();
        seconde.Encore.ShouldBeTrue();
        troisieme.Encore.ShouldBeFalse();

        var identifiants = premiere.Lignes
            .Concat(seconde.Lignes)
            .Concat(troisieme.Lignes)
            .Select(l => l.Id)
            .ToList();

        identifiants.Count.ShouldBe(12);
        identifiants.Distinct().Count().ShouldBe(12, "aucune ligne ne doit apparaître deux fois");
    }

    [Fact]
    public async Task Une_limite_au_dela_du_plafond_est_refusee()
    {
        // Vérifiée avant lecture : accepter puis rejeter ferait payer la requête.
        var (client, eventId) = await SoireeAsync();

        (await client.GetAsync(new Uri(
            $"/v1/events/{eventId}/activity?limit=5000", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task La_ligne_porte_ses_donnees_et_l_auteur()
    {
        var (client, eventId) = await SoireeAsync();
        await AjouterArticlesAsync(client, eventId, 1);

        var ligne = (await LirePageAsync(client, eventId, limite: 5)).Lignes[0];

        ligne.Auteur.ShouldBe("Camille");
        ligne.Categorie.ShouldBe(ActivityKinds.ItemCreated);
        ligne.Donnees.ShouldNotBeNull();
        ligne.Donnees!.Value.Texte("libelle").ShouldBe("Article 1");
    }

    private static Uri Chemin(string eventId) =>
        new($"/v1/events/{eventId}/activity", UriKind.Relative);

    private async Task<(HttpClient Client, string EventId)> SoireeAsync()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await organisateur.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        return (camille, eventId);
    }

    private static async Task AjouterArticlesAsync(HttpClient client, string eventId, int combien)
    {
        for (var rang = 1; rang <= combien; rang++)
        {
            (await client.PosterAsync(
                $"/v1/events/{eventId}/shopping",
                new { name = $"Article {rang}" })).EnsureSuccessStatusCode();
        }
    }

    private static async Task<PageLue> LirePageAsync(
        HttpClient client,
        string eventId,
        int limite,
        string? avant = null)
    {
        var chemin = $"/v1/events/{eventId}/activity?limit={limite}"
                     + (avant is null ? string.Empty : $"&before={avant}");

        var reponse = await client.GetAsync(new Uri(chemin, UriKind.Relative));
        reponse.EnsureSuccessStatusCode();

        var corps = (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!.RootElement;

        return new PageLue(
            [.. corps.GetProperty("items").EnumerateArray().Select(e => new LigneLue(
                e.GetProperty("id").GetString()!,
                e.GetProperty("actorName").GetString()!,
                e.GetProperty("kind").GetString()!,
                e.TryGetProperty("donnees", out var d) && d.ValueKind is not JsonValueKind.Null
                    ? d.Clone()
                    : null,
                e.GetProperty("createdAt").GetDateTimeOffset()))],
            corps.GetProperty("hasMore").GetBoolean());
    }

    private sealed record LigneLue(
        string Id,
        string Auteur,
        string Categorie,
        JsonElement? Donnees,
        DateTimeOffset Cree);

    private sealed record PageLue(IReadOnlyList<LigneLue> Lignes, bool Encore);
}
