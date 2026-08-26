namespace PartyPlan.IntegrationTests;

using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Lignes de fil produites par le module Shopping (RG-FIL-01).
/// <para>
/// La libération y figure autant que l'attribution : un fil qui montre un article pris
/// en charge par quelqu'un qui l'a relâché depuis est faux, et c'est exactement ce
/// qu'on relira en cas de désaccord.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FilActiviteShoppingTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Ajouter_un_article_consigne_son_libelle()
    {
        var (client, eventId) = await SoireeAsync();

        await AjouterAsync(client, eventId, "Glaçons");

        var (ligne, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ItemCreated);

        ligne.ActorName.ShouldBe("Camille");
        donnees.Texte("libelle").ShouldBe("Glaçons");
    }

    [Fact]
    public async Task Supprimer_un_article_consigne_son_libelle()
    {
        var (client, eventId) = await SoireeAsync();
        var itemId = await AjouterAsync(client, eventId, "Glaçons");

        (await client.DeleteAsync(new Uri(
            $"/v1/events/{eventId}/shopping/{itemId}", UriKind.Relative)))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ItemDeleted);

        // Le libellé est capturé avant la suppression : après, il n'est plus lisible.
        donnees.Texte("libelle").ShouldBe("Glaçons");
    }

    [Fact]
    public async Task Attribuer_puis_liberer_consigne_les_deux_mouvements()
    {
        var (client, eventId) = await SoireeAsync();
        var itemId = await AjouterAsync(client, eventId, "Glaçons");

        (await client.PosterAsync($"/v1/events/{eventId}/shopping/{itemId}/claim"))
            .EnsureSuccessStatusCode();
        (await client.DeleteAsync(
            new Uri($"/v1/events/{eventId}/shopping/{itemId}/claim", UriKind.Relative)))
            .EnsureSuccessStatusCode();

        (await fixture.UniqueActiviteAsync(eventId, ActivityKinds.ItemClaimed))
            .Donnees.Texte("libelle").ShouldBe("Glaçons");
        (await fixture.UniqueActiviteAsync(eventId, ActivityKinds.ItemUnclaimed))
            .Donnees.Texte("libelle").ShouldBe("Glaçons");
    }

    [Fact]
    public async Task Acheter_consigne_le_libelle_et_le_montant()
    {
        var (client, eventId) = await SoireeAsync();
        var itemId = await AjouterAsync(client, eventId, "Glaçons");

        (await client.PosterAsync(
            $"/v1/events/{eventId}/shopping/{itemId}/purchase",
            new { actualPrice = 4.50m }))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ItemPurchased);

        donnees.Texte("libelle").ShouldBe("Glaçons");
        donnees.Montant("montant").ShouldBe(4.50m);
    }

    [Fact]
    public async Task Acheter_sans_prix_consigne_le_libelle_seul()
    {
        var (client, eventId) = await SoireeAsync();
        var itemId = await AjouterAsync(client, eventId, "Glaçons");

        (await client.PosterAsync(
            $"/v1/events/{eventId}/shopping/{itemId}/purchase",
            new { }))
            .EnsureSuccessStatusCode();

        var (_, donnees) = await fixture.UniqueActiviteAsync(
            eventId, ActivityKinds.ItemPurchased);

        donnees.Texte("libelle").ShouldBe("Glaçons");
        // Pas de montant à zéro : rien n'a été déclaré, et zéro serait un prix.
        donnees.Montant("montant").ShouldBeNull();
    }

    [Fact]
    public async Task Un_ajout_refuse_ne_laisse_aucune_ligne()
    {
        // La garantie de transaction, éprouvée sur un vrai service.
        var (client, eventId) = await SoireeAsync();

        var refus = await client.PosterAsync(
            $"/v1/events/{eventId}/shopping",
            new { name = "   " });

        refus.IsSuccessStatusCode.ShouldBeFalse();
        (await fixture.ActivitesAsync(eventId, ActivityKinds.ItemCreated)).ShouldBeEmpty();
    }

    /// <summary>
    /// Une soirée dont l'acteur est un membre qui a rejoint, et non le créateur.
    /// <para>
    /// Le créateur reçoit un nom de membre en dur, « Organisateur » — comportement
    /// existant du module Events. Faire agir Camille éprouve le vrai chemin : le nom
    /// vient du profil (règle 7) et le fil le fige à l'écriture (RG-USR-04).
    /// </para>
    /// </summary>
    private async Task<(HttpClient Client, string EventId)> SoireeAsync()
    {
        var organisateur = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await organisateur.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);

        return (camille, eventId);
    }

    private static async Task<string> AjouterAsync(
        HttpClient client,
        string eventId,
        string libelle)
    {
        var creation = await client.PosterAsync(
            $"/v1/events/{eventId}/shopping",
            new { name = libelle });

        creation.EnsureSuccessStatusCode();

        return (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;
    }
}
