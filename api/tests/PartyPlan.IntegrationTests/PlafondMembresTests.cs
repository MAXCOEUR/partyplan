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
/// Plafond de vingt membres actifs par événement (RG-PRM-01, ADR 0008).
/// <para>
/// Deux règles s'y croisent et sont testées séparément : le plafond est celui du
/// propriétaire et non celui de l'arrivant (EF-PRM-03), et l'idempotence de l'adhésion
/// passe avant le quota (RG-INV-05) — sans quoi un simple doublon de requête refuserait
/// une adhésion déjà acquise.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class PlafondMembresTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    [Fact]
    public async Task La_vingt_et_unieme_adhesion_est_refusee()
    {
        using var organisateur = await CompteAsync("Organisateur");
        var (eventId, jeton) = await CreerAvecJetonAsync(organisateur, "Soirée pleine");

        // L'organisateur compte pour un membre : dix-neuf adhésions suffisent à remplir.
        await RemplirAsync(jeton, QuotaEvenements.MembresMaximum - 1);

        using var surnumeraire = await CompteAsync("Surnuméraire");
        var refus = await RejoindreAsync(surnumeraire, jeton);

        refus.StatusCode.ShouldBe(HttpStatusCode.Forbidden);
        (await CodeAsync(refus)).ShouldBe("plan.member_limit_reached");

        (await CompterMembresAsync(organisateur, eventId))
            .ShouldBe(QuotaEvenements.MembresMaximum);
    }

    [Fact]
    public async Task Un_membre_deja_present_rejoue_son_adhesion_a_vingt_sur_vingt()
    {
        using var organisateur = await CompteAsync("Organisateur");
        var (_, jeton) = await CreerAvecJetonAsync(organisateur, "Soirée pleine");

        var derniers = await RemplirAsync(jeton, QuotaEvenements.MembresMaximum - 1);
        var dernier = derniers[^1];

        // RG-INV-05 avant le quota : le lien est souvent réouvert, et un rejeu ne doit
        // pas être confondu avec une vingt-et-unième arrivée.
        (await RejoindreAsync(dernier, jeton)).StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Le_plafond_suit_le_proprietaire_pas_l_arrivant()
    {
        // Propriétaire abonné, arrivant gratuit : l'adhésion passe.
        using var abonne = await CompteAsync("Abonné");
        await RendreAbonneAsync(abonne);
        var (_, jetonAbonne) = await CreerAvecJetonAsync(abonne, "Soirée d'abonné");
        await RemplirAsync(jetonAbonne, QuotaEvenements.MembresMaximum - 1);

        using var invite = await CompteAsync("Invité gratuit");
        (await RejoindreAsync(invite, jetonAbonne)).StatusCode.ShouldBe(HttpStatusCode.OK);

        // Propriétaire gratuit, arrivant abonné : l'adhésion est refusée. La formule de
        // l'arrivant ne lève rien.
        using var gratuit = await CompteAsync("Organisateur gratuit");
        var (_, jetonGratuit) = await CreerAvecJetonAsync(gratuit, "Soirée gratuite");
        await RemplirAsync(jetonGratuit, QuotaEvenements.MembresMaximum - 1);

        using var arrivantAbonne = await CompteAsync("Arrivant abonné");
        await RendreAbonneAsync(arrivantAbonne);

        (await RejoindreAsync(arrivantAbonne, jetonGratuit)).StatusCode
            .ShouldBe(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task Les_accompagnants_ne_consomment_aucune_place()
    {
        using var organisateur = await CompteAsync("Organisateur");
        var (eventId, jeton) = await CreerAvecJetonAsync(organisateur, "Soirée avec renforts");

        // Dix-huit adhésions : dix-neuf membres avec l'organisateur.
        var membres = await RemplirAsync(jeton, QuotaEvenements.MembresMaximum - 2);

        // Le premier arrivé déclare dix accompagnants : trente têtes, dix-neuf membres.
        (await membres[0].PatchAsJsonAsync(
                $"/v1/events/{eventId}/members/me",
                new { status = "Going", extraGuests = 10 }))
            .StatusCode.ShouldBe(HttpStatusCode.OK);

        // RG-PRES-04 : présents et têtes sont deux décomptes distincts, et c'est le
        // décompte de membres qui borne la formule.
        using var vingtieme = await CompteAsync("Vingtième");
        (await RejoindreAsync(vingtieme, jeton)).StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Un_membre_exclu_libere_sa_place()
    {
        using var organisateur = await CompteAsync("Organisateur");
        var (eventId, jeton) = await CreerAvecJetonAsync(organisateur, "Soirée pleine");

        await RemplirAsync(jeton, QuotaEvenements.MembresMaximum - 1);

        using var refuse = await CompteAsync("Refusé");
        (await RejoindreAsync(refuse, jeton)).StatusCode.ShouldBe(HttpStatusCode.Forbidden);

        // RG-ROLE-03 : l'exclusion horodate la ligne sans la supprimer, mais la place est
        // rendue puisque le décompte ne porte que sur les membres actifs.
        var cible = await MembreIdAsync(organisateur, eventId, "Membre 1");
        (await organisateur.DeleteAsync(
                new Uri($"/v1/events/{eventId}/members/{cible}", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await RejoindreAsync(refuse, jeton)).StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task L_apercu_public_annonce_complet()
    {
        using var organisateur = await CompteAsync("Organisateur");
        var (eventId, jeton) = await CreerAvecJetonAsync(organisateur, "Soirée pleine");
        var code = await CodeCourtAsync(organisateur, eventId);

        (await CompletAsync($"/v1/join/{jeton}")).ShouldBeFalse();

        await RemplirAsync(jeton, QuotaEvenements.MembresMaximum - 1);

        // Annoncé avant toute création de compte : sans cela un invité s'inscrirait pour
        // découvrir ensuite qu'il ne peut pas entrer.
        (await CompletAsync($"/v1/join/{jeton}")).ShouldBeTrue();
        (await CompletAsync($"/v1/join/code/{code}")).ShouldBeTrue();
    }

    [Fact]
    public async Task Un_evenement_d_abonne_n_est_jamais_complet()
    {
        using var abonne = await CompteAsync("Abonné");
        await RendreAbonneAsync(abonne);
        var (_, jeton) = await CreerAvecJetonAsync(abonne, "Grande soirée");

        await RemplirAsync(jeton, QuotaEvenements.MembresMaximum + 4);

        (await CompletAsync($"/v1/join/{jeton}")).ShouldBeFalse();
    }

    // --------------------------------------------------------------- assistants ----

    /// <summary>
    /// Fait rejoindre <paramref name="combien"/> nouveaux comptes et renvoie leurs clients,
    /// dans l'ordre d'arrivée. Les noms sont numérotés pour que les tests puissent viser
    /// un membre précis.
    /// </summary>
    private async Task<List<HttpClient>> RemplirAsync(string jeton, int combien)
    {
        var clients = new List<HttpClient>();

        for (var i = 1; i <= combien; i++)
        {
            var client = await CompteAsync($"Membre {i}");
            clients.Add(client);

            (await RejoindreAsync(client, jeton)).StatusCode.ShouldBe(HttpStatusCode.OK);
        }

        return clients;
    }

    private static Task<HttpResponseMessage> RejoindreAsync(HttpClient client, string jeton) =>
        EvenementsTests.RejoindreBrutAsync(
            client,
            $"/v1/join/{jeton}",
            Guid.CreateVersion7().ToString());

    private async Task<bool> CompletAsync(string chemin)
    {
        using var anonyme = fixture.CreateClient();

        var apercu = await anonyme.GetFromJsonAsync<JsonDocument>(chemin);

        return apercu!.RootElement.GetProperty("complet").GetBoolean();
    }

    private static async Task<int> CompterMembresAsync(HttpClient client, string eventId)
    {
        var membres = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/members");

        return membres!.RootElement.GetArrayLength();
    }

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

    private static async Task<(string EventId, string Jeton)> CreerAvecJetonAsync(
        HttpClient client,
        string nom)
    {
        var creation = await EvenementsTests.CreerBrutAsync(
            client,
            new
            {
                name = nom,
                startsAt = DateTimeOffset.UtcNow.AddDays(7),
                address = "Replonges",
            });

        creation.StatusCode.ShouldBe(HttpStatusCode.OK);

        var eventId = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;

        var invitation = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/invitation");

        return (eventId, invitation!.RootElement.GetProperty("token").GetString()!);
    }

    private static async Task<string> CodeCourtAsync(HttpClient client, string eventId)
    {
        var invitation = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/invitation");

        return invitation!.RootElement.GetProperty("shortCode").GetString()!;
    }

    private static async Task<string?> CodeAsync(HttpResponseMessage reponse)
    {
        var corps = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        return corps!.RootElement.TryGetProperty("code", out var code) ? code.GetString() : null;
    }

    private async Task<HttpClient> CompteAsync(string nomAffiche)
    {
        var adresse = $"plafond-{Guid.CreateVersion7():N}@partyplan.test";

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
