namespace PartyPlan.IntegrationTests;

using System.Net;
using PartyPlan.IntegrationTests.Infrastructure;
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
}
