namespace PartyPlan.IntegrationTests;

using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.SignalR.Client;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Le temps réel, avec un vrai client SignalR.
/// <para>
/// Les autres tests vérifient que les services publient. Celui-ci vérifie qu'un
/// changement arrive jusqu'à un abonné, ce qui est une question différente : entre les
/// deux, il y a l'authentification du WebSocket, le contrôle d'appartenance à la
/// connexion, et l'appartenance au groupe. Les trois défauts du 25/08/2026 vivaient
/// précisément là, et aucun test sans client réel ne pouvait les voir.
/// </para>
/// <para>
/// Utilise une fabrique dédiée, sans la doublure de diffusion : ici c'est la vraie
/// diffusion SignalR qu'on éprouve.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class HubBoutEnBoutTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Un_membre_recoit_un_changement_diffuse()
    {
        var (client, jeton, evenement) = await SoireeAsync("Maxence");

        await using var connexion = Connexion(evenement, jeton);

        var recu = new TaskCompletionSource<string>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        connexion.On<string, object?>(
            "Changement",
            (message, _) => recu.TrySetResult(message));

        await connexion.StartAsync();

        connexion.State.ShouldBe(
            HubConnectionState.Connected,
            "un membre doit pouvoir s'abonner à sa propre soirée");

        // Un geste ordinaire, par REST, sur la même soirée.
        var envoi = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/events/{evenement}/messages", UriKind.Relative))
        {
            Content = JsonContent.Create(new { body = "On apporte quoi ?" }),
        };
        envoi.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        (await client.SendAsync(envoi)).EnsureSuccessStatusCode();

        var abandon = Task.Delay(TimeSpan.FromSeconds(10));
        var gagnant = await Task.WhenAny(recu.Task, abandon);

        gagnant.ShouldBe(
            recu.Task,
            "le changement doit arriver au client en moins de dix secondes");

        (await recu.Task).ShouldBe("message.created");
    }

    [Fact]
    public async Task Un_non_membre_ne_recoit_rien()
    {
        // RG-SEC-01 et RG-SEC-02 : le cloisonnement doit tenir sur le hub comme sur
        // REST. Un abonnement accepté diffuserait le contenu d'une soirée privée à un
        // inconnu, ce qui est le pire défaut possible de ce produit.
        //
        // L'assertion porte sur ce qui est reçu, et non sur l'échec de StartAsync : selon
        // le transport négocié, la connexion peut s'établir avant que le refus du hub ne
        // remonte au client. La garantie qui compte est qu'aucun message ne parvienne
        // jamais, et elle ne dépend pas du transport.
        var (client, _, evenement) = await SoireeAsync("Maxence");
        var (_, jetonDeLautre, _) = await SoireeAsync("Inconnu");

        await using var connexion = Connexion(evenement, jetonDeLautre);

        var recu = new TaskCompletionSource<string>(
            TaskCreationOptions.RunContinuationsAsynchronously);

        connexion.On<string, object?>(
            "Changement",
            (message, _) => recu.TrySetResult(message));

        try
        {
            await connexion.StartAsync();
        }
        catch (Exception)
        {
            // Refus immédiat : c'est le meilleur des cas, et il n'y a plus rien à
            // vérifier — aucun message ne peut arriver sur une connexion qui n'existe
            // pas.
            return;
        }

        var envoi = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/events/{evenement}/messages", UriKind.Relative))
        {
            Content = JsonContent.Create(new { body = "Contenu privé" }),
        };
        envoi.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        (await client.SendAsync(envoi)).EnsureSuccessStatusCode();

        var abandon = Task.Delay(TimeSpan.FromSeconds(3));

        (await Task.WhenAny(recu.Task, abandon)).ShouldBe(
            abandon,
            "un non-membre ne doit jamais recevoir le contenu d'une soirée privée");
    }

    /// <summary>Connexion au hub à travers le serveur de test, sans réseau réel.</summary>
    private HubConnection Connexion(Guid evenement, string jeton) =>
        new HubConnectionBuilder()
            .WithUrl(
                new Uri($"{fixture.Server.BaseAddress}hubs/event?eventId={evenement}"),
                options =>
                {
                    options.HttpMessageHandlerFactory = _ => fixture.Server.CreateHandler();
                    options.AccessTokenProvider = () => Task.FromResult<string?>(jeton);
                })
            .Build();

    private async Task<(HttpClient Client, string Jeton, Guid Evenement)> SoireeAsync(
        string nom)
    {
        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new
            {
                email = $"hub-{Guid.CreateVersion7():N}@partyplan.test",
                password = MotDePasse,
                displayName = nom,
            });

        inscription.EnsureSuccessStatusCode();

        var jeton = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString()!;

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", jeton);

        var creation = await EvenementsTests.CreerBrutAsync(client, new
        {
            name = $"Soirée de {nom}",
            startsAt = DateTimeOffset.UtcNow.AddDays(3),
        });

        creation.EnsureSuccessStatusCode();

        return (
            client,
            jeton,
            (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("id").GetGuid());
    }
}
