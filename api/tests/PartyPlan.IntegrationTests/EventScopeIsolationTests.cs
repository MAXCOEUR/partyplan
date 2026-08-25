namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Headers;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Cloisonnement des événements (RG-SEC-01, RG-SEC-02) et étanchéité des rôles
/// plateforme (RG-ADM-01). Ce sont les tests les plus importants du projet : leur
/// échec signifie que la promesse d'événement privé est fausse.
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class EventScopeIsolationTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    private Guid _eventId;
    private Guid _memberId;
    private Guid _memberUserId;
    private Guid _outsiderUserId;
    private Guid _adminUserId;
    private string _inviteToken = string.Empty;

    public async Task InitializeAsync()
    {
        _memberUserId = Guid.CreateVersion7();
        _outsiderUserId = Guid.CreateVersion7();
        _adminUserId = Guid.CreateVersion7();
        _eventId = Guid.CreateVersion7();
        _memberId = Guid.CreateVersion7();
        _inviteToken = Guid.NewGuid().ToString("N");

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.AddRange(
                NewUser(_memberUserId, "membre"),
                NewUser(_outsiderUserId, "etranger"),
                NewUser(_adminUserId, "admin", PlatformRole.PlatformAdmin));

            db.Events.Add(new Event
            {
                Id = _eventId,
                Name = "Anniversaire de test",
                StartsAt = DateTimeOffset.UtcNow.AddDays(3),
                InviteToken = _inviteToken,
                // Dérivé de l'identifiant et non tiré au hasard : « TST » + 3 chiffres
                // n'offrait que 900 valeurs pour une colonne unique, et chaque méthode de
                // test réamorce. La collision arrivait au hasard des exécutions.
                ShortCode = _eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = _memberUserId,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = _memberId,
                EventId = _eventId,
                UserId = _memberUserId,
                DisplayName = "Membre",
                Role = EventMemberRole.Owner,
                Status = EventMemberStatus.Going,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Un_membre_voit_son_evenement()
    {
        using var client = Client(TestTokens.ForUser(_memberUserId));

        var response = await client.GetAsync(EventUri());

        response.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync()).ShouldContain("Anniversaire de test");
    }

    [Fact]
    public async Task Un_utilisateur_non_membre_recoit_404_et_non_403()
    {
        using var client = Client(TestTokens.ForUser(_outsiderUserId));

        var response = await client.GetAsync(EventUri());

        // 404 et non 403 : un 403 confirmerait l'existence de l'événement (RG-SEC-02).
        response.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Un_administrateur_de_plateforme_non_membre_recoit_404()
    {
        using var client = Client(TestTokens.ForUser(_adminUserId, PlatformRole.PlatformAdmin));

        var response = await client.GetAsync(EventUri());

        // RG-ADM-01 : le rôle plateforme ne donne aucun accès au contenu d'un événement.
        response.StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Un_appelant_anonyme_recoit_401()
    {
        using var client = fixture.CreateClient();

        var response = await client.GetAsync(EventUri());

        response.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Un_ancien_jeton_invite_signe_est_refuse_sur_les_routes_protegees()
    {
        using var client = Client(TestTokens.ForLegacyGuest(_eventId, _memberId));
        using var rejoindre = new HttpRequestMessage(HttpMethod.Post, $"/v1/join/{_inviteToken}");
        rejoindre.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        (await client.GetAsync(EventUri())).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        (await client.SendAsync(rejoindre)).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    private Uri EventUri() => new($"/v1/events/{_eventId}", UriKind.Relative);

    private HttpClient Client(string token)
    {
        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    private static User NewUser(Guid id, string name, PlatformRole role = PlatformRole.User) => new()
    {
        Id = id,
        Email = $"{name}-{id:N}@partyplan.test",
        DisplayName = name,
        PlatformRole = role,
    };
}
