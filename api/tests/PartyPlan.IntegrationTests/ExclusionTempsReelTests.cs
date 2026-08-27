namespace PartyPlan.IntegrationTests;

using System.Collections.Concurrent;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Un membre exclu cesse de recevoir le temps réel de l'événement (règle 1, RG-SEC-02).
/// <para>
/// L'appartenance est vérifiée à l'établissement de la connexion et non à chaque
/// message : c'est le bon arbitrage, une vérification par message coûterait une requête
/// à chaque diffusion. Mais il impose de fermer la connexion à l'exclusion, sans quoi
/// l'exclu garde son abonnement et continue de recevoir les montants et la discussion
/// d'une soirée dont il n'est plus membre — alors que le REST lui est déjà fermé.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class ExclusionTempsReelTests(PartyPlanApiFixture fixture)
{
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(10);

    [Fact]
    public async Task Un_membre_exclu_ne_recoit_plus_rien()
    {
        var soiree = await SoireeADeuxAsync();

        await using var ecoute = Connexion(soiree.EventId, soiree.JetonCamille);
        var recus = new ConcurrentBag<string>();
        var premier = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        ecoute.On<string, object?>("Changement", (message, _) =>
        {
            recus.Add(message);
            premier.TrySetResult();
        });

        await ecoute.StartAsync();
        ecoute.State.ShouldBe(HubConnectionState.Connected);

        // Camille est bien abonnée avant l'exclusion : sans cette vérification, le test
        // passerait même si la connexion n'avait jamais fonctionné.
        (await soiree.Alex.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping",
            new { name = "Glaçons" })).EnsureSuccessStatusCode();

        (await Task.WhenAny(premier.Task, Task.Delay(Patience))).ShouldBe(
            premier.Task,
            "Camille doit recevoir tant qu'elle est membre");

        // Exclusion.
        (await soiree.Alex.DeleteAsync(new Uri(
            $"/v1/events/{soiree.EventId}/members/{soiree.MembreCamille}",
            UriKind.Relative))).EnsureSuccessStatusCode();

        // Laisser le retrait du groupe se propager.
        await Task.Delay(TimeSpan.FromSeconds(1));
        recus.Clear();

        (await soiree.Alex.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping",
            new { name = "Chips" })).EnsureSuccessStatusCode();

        await Task.Delay(TimeSpan.FromSeconds(2));

        recus.ShouldBeEmpty(
            $"une exclue ne doit plus rien recevoir ; reçus : {string.Join(", ", recus)}");
    }

    [Fact]
    public async Task Un_membre_qui_part_de_lui_meme_ne_recoit_plus_rien()
    {
        var soiree = await SoireeADeuxAsync();

        await using var ecoute = Connexion(soiree.EventId, soiree.JetonCamille);
        var recus = new ConcurrentBag<string>();
        ecoute.On<string, object?>("Changement", (message, _) => recus.Add(message));

        await ecoute.StartAsync();

        (await soiree.Camille.DeleteAsync(new Uri(
            $"/v1/events/{soiree.EventId}/members/me", UriKind.Relative)))
            .EnsureSuccessStatusCode();

        await Task.Delay(TimeSpan.FromSeconds(1));
        recus.Clear();

        (await soiree.Alex.PosterAsync(
            $"/v1/events/{soiree.EventId}/shopping",
            new { name = "Chips" })).EnsureSuccessStatusCode();

        await Task.Delay(TimeSpan.FromSeconds(2));

        recus.ShouldBeEmpty();
    }

    private HubConnection Connexion(string eventId, string jeton) =>
        new HubConnectionBuilder()
            .WithUrl(
                new Uri($"{fixture.Server.BaseAddress}hubs/event?eventId={eventId}"),
                options =>
                {
                    options.HttpMessageHandlerFactory = _ => fixture.Server.CreateHandler();
                    options.AccessTokenProvider = () => Task.FromResult<string?>(jeton);
                })
            .Build();

    private async Task<Soiree> SoireeADeuxAsync()
    {
        var (alex, _) = await fixture.CompteAvecJetonAsync("Alex");
        var (eventId, jetonInvitation) = await alex.CreerEvenementAsync();

        var (camille, jetonCamille) = await fixture.CompteAvecJetonAsync("Camille");
        await camille.RejoindreAsync(jetonInvitation);

        var membres = await alex.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        var membreCamille = membres!.RootElement.EnumerateArray()
            .First(m => m.GetProperty("displayName").GetString() == "Camille")
            .GetProperty("id").GetString()!;

        return new Soiree(alex, camille, jetonCamille, eventId, membreCamille);
    }

    private sealed record Soiree(
        HttpClient Alex,
        HttpClient Camille,
        string JetonCamille,
        string EventId,
        string MembreCamille);
}
