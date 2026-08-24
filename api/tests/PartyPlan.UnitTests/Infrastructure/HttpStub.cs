namespace PartyPlan.UnitTests.Infrastructure;

using System.Net;

/// <summary>
/// Gestionnaire HTTP substitué. La frontière des tests est le <c>HttpClient</c> : aucun
/// test ne sort sur le réseau (NF-DEV-10).
/// </summary>
internal sealed class HttpStub(Func<HttpRequestMessage, HttpResponseMessage> repondre)
    : HttpMessageHandler
{
    /// <summary>Requêtes reçues, dans l'ordre. Le corps est déjà lu.</summary>
    internal List<(string Uri, string Corps)> Appels { get; } = [];

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var corps = request.Content is null
            ? string.Empty
            : await request.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

        Appels.Add((request.RequestUri!.ToString(), corps));

        return repondre(request);
    }

    internal static HttpResponseMessage Json(HttpStatusCode statut, string corps) =>
        new(statut) { Content = new StringContent(corps, System.Text.Encoding.UTF8, "application/json") };
}
