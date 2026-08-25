namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Cloisonnement du hub temps réel (RG-RT-01, RG-SEC-01, RG-SEC-02).
/// <para>
/// Ce sont les seuls tests d'intégration du temps réel : la mécanique de SignalR est
/// celle du framework, ce qui nous appartient est de refuser les non-membres. Un hub qui
/// laisserait passer diffuserait le contenu d'un événement privé à un inconnu.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class TempsReelTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Le_hub_est_expose_et_refuse_un_appelant_anonyme()
    {
        using var client = fixture.CreateClient();

        // La négociation SignalR est un POST : un GET est refusé par le framework, ce
        // qui ne nous apprendrait rien. C'est bien la négociation qu'on interroge.
        var reponse = await client.PostAsync(
            new Uri("/hubs/event/negotiate?negotiateVersion=1", UriKind.Relative),
            content: null);

        // 401 et non 404 : la route existe, c'est la session qui manque.
        reponse.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Une_adhesion_et_un_changement_de_presence_sont_diffuses()
    {
        var (organisateur, evenement) = await SoireeAsync();
        fixture.Diffusions.Clear();

        var (membre, _) = await RejoindreAsync(evenement, organisateur, "Lucas");

        // Le nouvel arrivant doit apparaître chez les autres sans qu'ils rechargent.
        Messages().ShouldContain(MessagesTempsReel.MembreArrive);

        fixture.Diffusions.Clear();

        (await membre.PatchAsJsonAsync(
                new Uri($"/v1/events/{evenement}/members/me", UriKind.Relative),
                new { status = "Going" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        Messages().ShouldContain(MessagesTempsReel.MembreStatutChange);

        // L'état résultant voyage avec le message (RG-RT-02) : sans lui, le rapiéçage
        // futur serait impossible sans toucher au serveur.
        fixture.Diffusions.Publications
            .Last(p => p.Message == MessagesTempsReel.MembreStatutChange)
            .Charge.ShouldNotBeNull();
    }

    [Fact]
    public async Task Une_modification_de_l_evenement_est_diffusee()
    {
        var (organisateur, evenement) = await SoireeAsync();
        fixture.Diffusions.Clear();

        (await organisateur.PatchAsJsonAsync(
                new Uri($"/v1/events/{evenement}", UriKind.Relative),
                new { name = "Raclette, finalement" }))
            .IsSuccessStatusCode.ShouldBeTrue();

        // Un changement de date ou de lieu est ce qui compte le plus pour les invités.
        Messages().ShouldContain(MessagesTempsReel.EvenementModifie);
    }

    // ------------------------------------------------------------------ aides ----

    private const string MotDePasse = "Trombone-Nuage-42x";

    private IReadOnlyList<string> Messages() =>
        [.. fixture.Diffusions.Publications.Select(p => p.Message)];

    private async Task<(HttpClient Organisateur, Guid Evenement)> SoireeAsync()
    {
        var organisateur = await CompteAsync("Maxence");

        var creation = await EvenementsTests.CreerBrutAsync(organisateur, new
        {
            name = "Temps réel",
            startsAt = DateTimeOffset.UtcNow.AddDays(3),
        });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var id = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetGuid();

        return (organisateur, id);
    }

    private async Task<(HttpClient Client, Guid MembreId)> RejoindreAsync(
        Guid evenement,
        HttpClient organisateur,
        string nom)
    {
        var invitation = await organisateur.GetFromJsonAsync<JsonDocument>(
            new Uri($"/v1/events/{evenement}/invitation", UriKind.Relative));

        var client = await CompteAsync(nom);

        var adhesion = await EvenementsTests.RejoindreBrutAsync(
            client,
            $"/v1/join/{invitation!.RootElement.GetProperty("token").GetString()!}",
            Guid.CreateVersion7().ToString());

        adhesion.StatusCode.ShouldBe(HttpStatusCode.OK);

        return (
            client,
            (await adhesion.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("memberId").GetGuid());
    }

    private async Task<HttpClient> CompteAsync(string nom)
    {
        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new
            {
                email = $"rt-{Guid.CreateVersion7():N}@partyplan.test",
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
}
