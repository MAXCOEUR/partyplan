namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Quota de trois événements possédés simultanément (RG-PRM-01, ADR 0008).
/// <para>
/// Le point renversé par rapport à la conception du 25/08/2026 est testé explicitement :
/// une soirée terminée libère sa place d'elle-même. L'ancienne règle exigeait une
/// suppression, donc la destruction des dépenses et des remboursements de la soirée
/// effacée.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class QuotaEvenementsApiTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task Trois_creations_passent_la_quatrieme_est_refusee()
    {
        using var organisateur = await CompteAsync();

        for (var i = 1; i <= QuotaEvenements.EvenementsMaximum; i++)
        {
            (await CreerAsync(organisateur, $"Soirée {i}")).StatusCode
                .ShouldBe(HttpStatusCode.OK);
        }

        var refus = await CreerAsync(organisateur, "Soirée de trop");

        refus.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await CodeAsync(refus)).ShouldBe("plan.event_quota_reached");
    }

    [Fact]
    public async Task Une_soiree_terminee_rend_sa_place_sans_rien_supprimer()
    {
        using var organisateur = await CompteAsync();

        // Deux soirées à venir, une déjà terminée : trois possédées, mais une seule
        // place occupée par du passé.
        await CreerAsync(organisateur, "À venir 1");
        await CreerAsync(organisateur, "À venir 2");
        var terminee = await CreerTermineeAsync(organisateur, "Soirée passée");

        (await CreerAsync(organisateur, "Nouvelle soirée")).StatusCode
            .ShouldBe(HttpStatusCode.OK);

        // La place est rendue sans que l'historique ait été détruit : la soirée passée
        // reste lisible.
        (await organisateur.GetAsync(new Uri($"/v1/events/{terminee}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Supprimer_une_soiree_rend_sa_place()
    {
        using var organisateur = await CompteAsync();

        var premiere = await CreerEtLireIdAsync(organisateur, "Soirée 1");
        await CreerAsync(organisateur, "Soirée 2");
        await CreerAsync(organisateur, "Soirée 3");

        (await CreerAsync(organisateur, "Refusée")).StatusCode
            .ShouldBe(HttpStatusCode.Forbidden);

        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{premiere}?force=true", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CreerAsync(organisateur, "Acceptée")).StatusCode
            .ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Un_abonne_depasse_le_quota()
    {
        using var organisateur = await CompteAsync();
        await RendreAbonneAsync(organisateur);

        for (var i = 1; i <= 6; i++)
        {
            (await CreerAsync(organisateur, $"Soirée d'abonné {i}")).StatusCode
                .ShouldBe(HttpStatusCode.OK);
        }
    }

    [Fact]
    public async Task Etre_membre_sans_posseder_ne_consomme_rien()
    {
        using var alice = await CompteAsync("Alice");
        using var bob = await CompteAsync("Bob");

        // Alice possède trois soirées et y invite Bob.
        for (var i = 1; i <= QuotaEvenements.EvenementsMaximum; i++)
        {
            var jeton = await JetonAsync(alice, $"Soirée d'Alice {i}");
            (await EvenementsTests.RejoindreBrutAsync(
                    bob,
                    $"/v1/join/{jeton}",
                    Guid.CreateVersion7().ToString()))
                .StatusCode.ShouldBe(HttpStatusCode.OK);
        }

        // Bob est membre de trois soirées et n'en possède aucune : son quota est intact.
        for (var i = 1; i <= QuotaEvenements.EvenementsMaximum; i++)
        {
            (await CreerAsync(bob, $"Soirée de Bob {i}")).StatusCode
                .ShouldBe(HttpStatusCode.OK);
        }
    }

    [Fact]
    public async Task Un_transfert_libere_la_place_du_cedant()
    {
        using var alice = await CompteAsync("Alice");
        using var bob = await CompteAsync("Bob");

        var (eventId, jeton) = await CreerAvecJetonAsync(alice, "Soirée cédée");
        await CreerAsync(alice, "Soirée 2");
        await CreerAsync(alice, "Soirée 3");

        (await CreerAsync(alice, "Refusée")).StatusCode.ShouldBe(HttpStatusCode.Forbidden);

        await EvenementsTests.RejoindreBrutAsync(
            bob,
            $"/v1/join/{jeton}",
            Guid.CreateVersion7().ToString());

        var membreBob = await MembreIdAsync(alice, eventId, "Bob");

        (await EvenementsTests.TransfererBrutAsync(
                alice,
                eventId,
                membreBob,
                Guid.CreateVersion7().ToString()))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // Alice ne possède plus que deux soirées : la propriété se lit sur le rôle, pas
        // sur le créateur historique.
        (await CreerAsync(alice, "Acceptée après transfert")).StatusCode
            .ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Au_dela_du_quota_apres_transfert_tout_reste_utilisable()
    {
        using var alice = await CompteAsync("Alice");
        using var bob = await CompteAsync("Bob");

        // Bob possède déjà ses trois soirées.
        for (var i = 1; i <= QuotaEvenements.EvenementsMaximum; i++)
        {
            await CreerAsync(bob, $"Soirée de Bob {i}");
        }

        // Alice lui transfère une quatrième : le transfert ne vérifie rien, sinon
        // RG-ROLE-02 deviendrait un cul-de-sac.
        var (eventId, jeton) = await CreerAvecJetonAsync(alice, "Quatrième de Bob");
        await EvenementsTests.RejoindreBrutAsync(
            bob,
            $"/v1/join/{jeton}",
            Guid.CreateVersion7().ToString());

        var membreBob = await MembreIdAsync(alice, eventId, "Bob");

        (await EvenementsTests.TransfererBrutAsync(
                alice,
                eventId,
                membreBob,
                Guid.CreateVersion7().ToString()))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        // RG-PRM-02 et RG-PRM-03 : l'événement reste consultable et modifiable.
        (await bob.GetAsync(new Uri($"/v1/events/{eventId}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        (await bob.PatchAsJsonAsync(
                $"/v1/events/{eventId}",
                new { name = "Quatrième de Bob, renommée" }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        // Seule une création supplémentaire est refusée.
        (await CreerAsync(bob, "Cinquième")).StatusCode.ShouldBe(HttpStatusCode.Forbidden);
    }

    // --------------------------------------------------------------- assistants ----

    private static Task<HttpResponseMessage> CreerAsync(HttpClient client, string nom) =>
        EvenementsTests.CreerBrutAsync(
            client,
            new
            {
                name = nom,
                startsAt = DateTimeOffset.UtcNow.AddDays(7),
                address = "Replonges",
            });

    /// <summary>
    /// Crée une soirée déjà terminée. Aucune validation n'interdit une date passée : la
    /// saisie d'un événement après coup est un usage légitime.
    /// </summary>
    private static async Task<string> CreerTermineeAsync(HttpClient client, string nom)
    {
        var creation = await EvenementsTests.CreerBrutAsync(
            client,
            new
            {
                name = nom,
                startsAt = DateTimeOffset.UtcNow.AddDays(-10),
                endsAt = DateTimeOffset.UtcNow.AddDays(-10).AddHours(6),
                address = "Replonges",
            });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        return await IdAsync(creation);
    }

    private static async Task<string> CreerEtLireIdAsync(HttpClient client, string nom)
    {
        var creation = await CreerAsync(client, nom);
        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        return await IdAsync(creation);
    }

    private static async Task<string> IdAsync(HttpResponseMessage reponse) =>
        (await reponse.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;

    private static async Task<(string EventId, string Jeton)> CreerAvecJetonAsync(
        HttpClient client,
        string nom)
    {
        var eventId = await CreerEtLireIdAsync(client, nom);

        var invitation = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/invitation");

        return (eventId, invitation!.RootElement.GetProperty("token").GetString()!);
    }

    private static async Task<string> JetonAsync(HttpClient client, string nom) =>
        (await CreerAvecJetonAsync(client, nom)).Jeton;

    private static async Task<string> MembreIdAsync(
        HttpClient client,
        string eventId,
        string nomAffiche)
    {
        var membres = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        return membres!.RootElement.EnumerateArray()
            .First(m => m.GetProperty("displayName").GetString() == nomAffiche)
            .GetProperty("id").GetString()!;
    }

    private static async Task<string?> CodeAsync(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }

    private async Task<HttpClient> CompteAsync(string nomAffiche = "Organisateur")
    {
        var adresse = $"quota-{Guid.CreateVersion7():N}@partyplan.test";

        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync(
            "/v1/auth/register",
            new
            {
                email = adresse,
                password = MotDePasse,
                displayName = nomAffiche,
            });

        inscription.StatusCode.ShouldBe(HttpStatusCode.OK);

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", acces);

        return client;
    }

    /// <summary>
    /// Rend le compte abonné en base : aucun endpoint d'attribution n'existe encore à ce
    /// stade du lot, et la formule est un attribut de compte.
    /// </summary>
    private async Task RendreAbonneAsync(HttpClient client)
    {
        var profil = await client.GetFromJsonAsync<JsonDocument>("/v1/me");
        var userId = profil!.RootElement.GetProperty("id").GetGuid();

        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.FirstAsync(u => u.Id == userId);
            compte.PremiumUntil = DateTimeOffset.UtcNow.AddDays(30);
            await db.SaveChangesAsync();
        });
    }
}
