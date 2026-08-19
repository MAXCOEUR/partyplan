namespace PartyPlan.IntegrationTests;

using System.Net;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

[Collection(ApiTestSuite.Name)]
public sealed class HealthAndContractTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Vivacite_repond_sans_dependance()
    {
        using var client = fixture.CreateClient();

        var response = await client.GetAsync(new Uri("/health/live", UriKind.Relative));

        response.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Disponibilite_verifie_la_base()
    {
        using var client = fixture.CreateClient();

        var response = await client.GetAsync(new Uri("/health/ready", UriKind.Relative));

        response.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await response.Content.ReadAsStringAsync()).ShouldBe("Healthy");
    }

    [Fact]
    public async Task Le_contrat_openapi_est_publie()
    {
        using var client = fixture.CreateClient();

        var response = await client.GetAsync(new Uri("/openapi/v1.json", UriKind.Relative));

        response.StatusCode.ShouldBe(HttpStatusCode.OK);
        var body = await response.Content.ReadAsStringAsync();
        body.ShouldContain("PartyPlan API");
        body.ShouldContain("/v1/events/{eventId}");
    }

    [Fact]
    public async Task Les_entetes_de_securite_sont_presents()
    {
        using var client = fixture.CreateClient();

        var response = await client.GetAsync(new Uri("/health/live", UriKind.Relative));

        response.Headers.GetValues("X-Content-Type-Options").ShouldContain("nosniff");
        response.Headers.GetValues("X-Robots-Tag").ShouldContain("noindex, nofollow");
        response.Headers.Contains("X-Correlation-Id").ShouldBeTrue();
    }

    [Fact]
    public async Task L_identifiant_de_correlation_fourni_est_repris()
    {
        using var client = fixture.CreateClient();
        using var request = new HttpRequestMessage(HttpMethod.Get, new Uri("/health/live", UriKind.Relative));
        request.Headers.Add("X-Correlation-Id", "trace-de-test-1234");

        var response = await client.SendAsync(request);

        response.Headers.GetValues("X-Correlation-Id").ShouldContain("trace-de-test-1234");
    }
}
