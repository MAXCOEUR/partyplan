namespace PartyPlan.IntegrationTests.Infrastructure;

using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Domain;
using Shouldly;

/// <summary>
/// Amorçage commun aux tests du fil d'activité.
/// <para>
/// Écrit une fois ici plutôt que recopié dans les cinq fichiers du lot : les aides des
/// suites existantes sont privées et dupliquées, et une sixième copie rendrait un
/// changement de contrat d'API pénible à répercuter.
/// </para>
/// </summary>
internal static class ScenarioFil
{
    private const string MotDePasse = "Trombone-Nuage-42x";

    /// <summary>Crée un compte et rend un client authentifié.</summary>
    internal static async Task<HttpClient> CompteAsync(
        this PartyPlanApiFixture fixture,
        string nomAffiche = "Camille")
    {
        ArgumentNullException.ThrowIfNull(fixture);

        using var anonyme = fixture.CreateClient();

        var inscription = await anonyme.PostAsJsonAsync("/v1/auth/register", new
        {
            email = $"fil-{Guid.CreateVersion7():N}@partyplan.test",
            password = MotDePasse,
            displayName = nomAffiche,
        });

        inscription.EnsureSuccessStatusCode();

        var acces = (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("accessToken").GetString();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", acces);

        return client;
    }

    /// <summary>Crée un événement et rend son identifiant et son jeton d'invitation.</summary>
    internal static async Task<(string EventId, string Jeton)> CreerEvenementAsync(
        this HttpClient client,
        string nom = "Soirée du fil")
    {
        ArgumentNullException.ThrowIfNull(client);

        var requete = new HttpRequestMessage(HttpMethod.Post, new Uri("/v1/events", UriKind.Relative))
        {
            Content = JsonContent.Create(new
            {
                name = nom,
                startsAt = DateTimeOffset.UtcNow.AddDays(7),
                address = "Replonges",
            }),
        };
        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        var creation = await client.SendAsync(requete);
        creation.EnsureSuccessStatusCode();

        var eventId = (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
            .RootElement.GetProperty("id").GetString()!;

        var invitation = await client.GetFromJsonAsync<JsonDocument>(
            $"/v1/events/{eventId}/invitation");

        return (eventId, invitation!.RootElement.GetProperty("token").GetString()!);
    }

    /// <summary>Fait rejoindre l'événement au compte du client.</summary>
    internal static async Task RejoindreAsync(this HttpClient client, string jeton)
    {
        ArgumentNullException.ThrowIfNull(client);

        var requete = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/join/{jeton}", UriKind.Relative));
        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        (await client.SendAsync(requete)).EnsureSuccessStatusCode();
    }

    /// <summary>
    /// POST avec en-tête d'idempotence. Plusieurs endpoints d'écriture l'exigent
    /// (RequireIdempotency), et l'oublier rend un 400 qui ressemble à une erreur de
    /// contrat plutôt qu'à un en-tête manquant.
    /// </summary>
    internal static Task<HttpResponseMessage> PosterAsync(
        this HttpClient client,
        string chemin,
        object? corps = null)
    {
        ArgumentNullException.ThrowIfNull(client);

        var requete = new HttpRequestMessage(HttpMethod.Post, new Uri(chemin, UriKind.Relative));
        if (corps is not null)
        {
            requete.Content = JsonContent.Create(corps);
        }

        requete.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        return client.SendAsync(requete);
    }

    /// <summary>
    /// Lignes du fil, sans filtre de cloisonnement : aucun périmètre n'est amorcé hors
    /// d'une requête HTTP, et le filtre global renverrait donc zéro ligne.
    /// </summary>
    internal static async Task<List<ActivityEntry>> ActivitesAsync(
        this PartyPlanApiFixture fixture,
        string eventId)
    {
        ArgumentNullException.ThrowIfNull(fixture);

        var id = Guid.Parse(eventId);
        List<ActivityEntry> lignes = [];

        await fixture.WithDatabaseAsync(async db =>
            lignes = await db.ActivityEntries
                .IgnoreQueryFilters()
                .Where(a => a.EventId == id)
                .OrderBy(a => a.CreatedAt)
                .ToListAsync());

        return lignes;
    }

    /// <summary>Lignes d'une catégorie donnée.</summary>
    internal static async Task<List<ActivityEntry>> ActivitesAsync(
        this PartyPlanApiFixture fixture,
        string eventId,
        string categorie)
    {
        var lignes = await fixture.ActivitesAsync(eventId);
        return [.. lignes.Where(a => a.Kind == categorie)];
    }

    /// <summary>
    /// L'unique ligne d'une catégorie, avec son payload analysé.
    /// <para>
    /// Analysé et non comparé en chaîne : PostgreSQL renormalise le <c>jsonb</c> à
    /// l'écriture — <c>{"de":"X"}</c> revient en <c>{"de": "X"}</c>. Une assertion sur
    /// le texte brut dépendrait du formatage de la base plutôt que du contenu.
    /// </para>
    /// </summary>
    internal static async Task<(ActivityEntry Ligne, JsonElement Donnees)> UniqueActiviteAsync(
        this PartyPlanApiFixture fixture,
        string eventId,
        string categorie)
    {
        var ligne = (await fixture.ActivitesAsync(eventId, categorie)).ShouldHaveSingleItem();
        var brut = ligne.Payload.ShouldNotBeNull();
        return (ligne, JsonDocument.Parse(brut).RootElement);
    }

    /// <summary>Valeur texte d'un champ du payload.</summary>
    internal static string? Texte(this JsonElement donnees, string cle) =>
        donnees.TryGetProperty(cle, out var valeur) ? valeur.GetString() : null;

    /// <summary>Valeur décimale d'un champ du payload.</summary>
    internal static decimal? Montant(this JsonElement donnees, string cle) =>
        donnees.TryGetProperty(cle, out var valeur) ? valeur.GetDecimal() : null;

    /// <summary>Liste de chaînes d'un champ du payload.</summary>
    internal static IReadOnlyList<string> Liste(this JsonElement donnees, string cle) =>
        donnees.TryGetProperty(cle, out var valeur)
            ? [.. valeur.EnumerateArray().Select(e => e.GetString()!)]
            : [];
}
