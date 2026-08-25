namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Fournisseurs tiers dont l'instance possède les clés, pour un appelant anonyme.
/// <para>
/// L'écran de connexion en a besoin avant toute session : sans cela il afficherait un
/// bouton « Continuer avec Google » sur une instance qui n'a pas de clé Google, donc un
/// bouton condamné à échouer. <c>GET /v1/auth/providers</c> ne peut pas servir ici, il
/// exige d'être authentifié et répond sur le compte courant.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FournisseursDisponiblesTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Un_appelant_anonyme_obtient_la_liste()
    {
        using var client = fixture.CreateClient();

        var reponse = await client.GetAsync(
            new Uri("/v1/auth/providers/available", UriKind.Relative));

        reponse.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Sans_cle_configuree_aucun_fournisseur_n_est_annonce_disponible()
    {
        using var client = fixture.CreateClient();

        var corps = await client.GetFromJsonAsync<JsonDocument>(
            new Uri("/v1/auth/providers/available", UriKind.Relative));

        var fournisseurs = corps!.RootElement.GetProperty("providers");

        // La fixture ne pose aucune clé Google : l'instance doit l'avouer plutôt que de
        // laisser l'application proposer une connexion impossible (NF-DEV-05).
        fournisseurs.EnumerateArray().ShouldNotBeEmpty();

        foreach (var fournisseur in fournisseurs.EnumerateArray())
        {
            fournisseur.GetProperty("configured").GetBoolean().ShouldBeFalse();
        }
    }

    [Fact]
    public async Task Aucune_donnee_de_compte_ne_transparait()
    {
        using var client = fixture.CreateClient();

        var brut = await client.GetStringAsync(
            new Uri("/v1/auth/providers/available", UriKind.Relative));

        // Le point est anonyme : il annonce ce que l'instance sait faire, jamais l'état
        // d'un compte. « linked » ou « hasPassword » ici seraient une fuite.
        brut.ShouldNotContain("linked");
        brut.ShouldNotContain("hasPassword");
    }
}
