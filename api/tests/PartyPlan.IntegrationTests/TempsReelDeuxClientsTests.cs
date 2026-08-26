namespace PartyPlan.IntegrationTests;

using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR.Client;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Deux membres, deux connexions : ce que l'un fait parvient à l'autre (lot 1.6).
/// <para>
/// Les autres tests du temps réel vérifient qu'un service publie, ou qu'un abonné
/// reçoit. Celui-ci met les deux bouts en présence, ce qui est la seule façon de voir
/// qu'un message manque — un <c>activity.appended</c> jamais diffusé ne se remarque
/// nulle part ailleurs, l'endpoint REST répondant correctement.
/// </para>
/// <para>
/// <b>Ce test ne couvre pas NF-PERF-05.</b> La règle demande une propagation en moins
/// d'une seconde sur de vrais appareils et un vrai réseau ; deux connexions dans le même
/// processus mesurent la logique de diffusion, pas la latence. Cette recette-là reste
/// ouverte et remonte au lot 1.17.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class TempsReelDeuxClientsTests(PartyPlanApiFixture fixture)
{
    /// <summary>
    /// Borne pour échouer au lieu de rester suspendu, et non une exigence de
    /// performance. Serrée, elle rendrait le test instable dès que la machine est
    /// chargée — et un test instable finit ignoré.
    /// </summary>
    private static readonly TimeSpan Patience = TimeSpan.FromSeconds(30);

    [Fact]
    public async Task Ce_qu_un_membre_fait_parvient_a_l_autre()
    {
        var (alex, camille, eventId) = await SoireeADeuxAsync();

        await using var ecoute = Connexion(eventId, camille.Jeton);
        var recus = new ConcurrentBag<string>();
        var attendu = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        ecoute.On<string, object?>("Changement", (message, _) =>
        {
            recus.Add(message);

            // Les deux messages, volontairement : l'écran des courses et l'écran du fil
            // ne lisent pas la même chose.
            if (recus.Contains("item.created") && recus.Contains("activity.appended"))
            {
                attendu.TrySetResult();
            }
        });

        await ecoute.StartAsync();
        ecoute.State.ShouldBe(HubConnectionState.Connected);

        (await alex.Client.PosterAsync(
            $"/v1/events/{eventId}/shopping",
            new { name = "Glaçons" })).EnsureSuccessStatusCode();

        (await Task.WhenAny(attendu.Task, Task.Delay(Patience))).ShouldBe(
            attendu.Task,
            $"les deux messages doivent arriver ; reçus : {string.Join(", ", recus)}");

        recus.ShouldContain("item.created");
        recus.ShouldContain("activity.appended");
    }

    [Fact]
    public async Task Une_action_qui_ne_consigne_rien_ne_diffuse_pas_de_ligne_de_fil()
    {
        // Envoyer un message de discussion n'entre pas dans les catégories de
        // RG-FIL-01 : diffuser activity.appended ferait clignoter le fil sans qu'aucune
        // ligne n'existe derrière.
        var (alex, camille, eventId) = await SoireeADeuxAsync();

        await using var ecoute = Connexion(eventId, camille.Jeton);
        var recus = new ConcurrentBag<string>();
        var premier = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

        ecoute.On<string, object?>("Changement", (message, _) =>
        {
            recus.Add(message);
            premier.TrySetResult();
        });

        await ecoute.StartAsync();

        (await alex.Client.PosterAsync(
            $"/v1/events/{eventId}/messages",
            new { body = "On apporte quoi ?" })).EnsureSuccessStatusCode();

        (await Task.WhenAny(premier.Task, Task.Delay(Patience))).ShouldBe(premier.Task);

        // Laisser passer un éventuel second message avant de conclure.
        await Task.Delay(TimeSpan.FromSeconds(1));

        recus.ShouldContain("message.created");
        recus.ShouldNotContain("activity.appended");
    }

    [Fact]
    public async Task Un_non_membre_ne_recoit_aucune_ligne_de_fil()
    {
        // RG-SEC-02. Le fil porte les montants et qui doit quoi : une fuite y est pire
        // qu'ailleurs.
        var (alex, _, eventId) = await SoireeADeuxAsync();
        var intrus = await InscrireAsync("Intrus");

        await using var ecoute = Connexion(eventId, intrus.Jeton);
        var recus = new ConcurrentBag<string>();
        ecoute.On<string, object?>("Changement", (message, _) => recus.Add(message));

        try
        {
            await ecoute.StartAsync();
        }
        catch (Exception)
        {
            // Refus immédiat : rien ne peut arriver sur une connexion qui n'existe pas.
            return;
        }

        (await alex.Client.PosterAsync(
            $"/v1/events/{eventId}/shopping",
            new { name = "Glaçons" })).EnsureSuccessStatusCode();

        await Task.Delay(TimeSpan.FromSeconds(3));

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

    private async Task<(Membre Alex, Membre Camille, string EventId)> SoireeADeuxAsync()
    {
        var alex = await InscrireAsync("Alex");
        var (eventId, jetonInvitation) = await alex.Client.CreerEvenementAsync();

        var camille = await InscrireAsync("Camille");
        await camille.Client.RejoindreAsync(jetonInvitation);

        return (alex, camille, eventId);
    }

    private async Task<Membre> InscrireAsync(string nom)
    {
        var (client, jeton) = await fixture.CompteAvecJetonAsync(nom);
        return new Membre(client, jeton);
    }

    private sealed record Membre(HttpClient Client, string Jeton);
}
