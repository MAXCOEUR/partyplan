namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Users.Application;
using Shouldly;
using Xunit;

/// <summary>
/// Administrateur d'amorçage hors production.
/// <para>
/// En production, le mot de passe d'amorçage n'est jamais réappliqué : il figure dans un
/// fichier de configuration, il doit être changé une fois puis retiré (RG-ADM-10,
/// RG-ADM-12). En développement, cette prudence rend le compte inutilisable dès qu'on a
/// changé son mot de passe une fois — et l'identifiant documenté ne fonctionne plus.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class AdminDeDeveloppementTests(PartyPlanApiFixture fixture)
{
    private const string Adresse = "admin@partyplan.test";
    private const string MotDePasseAmorce = "MotDePasseDeTest2026";

    [Fact]
    public async Task Le_compte_amorce_reste_utilisable_apres_un_changement()
    {
        // Ce que fait quiconque suit le README : se connecter avec l'identifiant
        // documenté. Après un changement de mot de passe — imposé à la première
        // connexion — puis un redémarrage, il doit encore fonctionner.
        await ChangerLeMotDePasseAsync("UnAutreMotDePasse2026!");
        await ReamorcerAsync();

        using var client = fixture.CreateClient();
        var connexion = await client.PostAsJsonAsync(
            new Uri("/v1/auth/login", UriKind.Relative),
            new { email = Adresse, password = MotDePasseAmorce });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    [Fact]
    public async Task Le_compte_amorce_n_exige_pas_de_changement_en_developpement()
    {
        // Imposer le changement à chaque démarrage ferait tomber sur le formulaire de
        // changement de mot de passe à chaque lancement de l'environnement local.
        await ReamorcerAsync();

        using var client = fixture.CreateClient();
        var connexion = await client.PostAsJsonAsync(
            new Uri("/v1/auth/login", UriKind.Relative),
            new { email = Adresse, password = MotDePasseAmorce });

        connexion.StatusCode.ShouldBe(HttpStatusCode.OK);

        var jetons = await connexion.Content.ReadFromJsonAsync<JsonDocument>();
        var jeton = jetons!.RootElement.GetProperty("accessToken").GetString();

        using var connecte = fixture.CreateClient();
        connecte.DefaultRequestHeaders.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", jeton);

        // Une lecture ordinaire passe : rien n'est bloqué en attente d'un changement.
        (await connecte.GetAsync(new Uri("/v1/me", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
    }

    // ------------------------------------------------------------------ aides ----

    /// <summary>Change le mot de passe de l'administrateur, directement en base.</summary>
    private async Task ChangerLeMotDePasseAsync(string nouveau)
    {
        using var portee = fixture.Services.CreateScope();
        var db = portee.ServiceProvider.GetRequiredService<PartyPlanDbContext>();
        var hasher = portee.ServiceProvider
            .GetRequiredService<PartyPlan.SharedKernel.Contracts.IPasswordHasher>();

        var admin = await db.Users
            .IgnoreQueryFilters()
            .FirstAsync(u => u.Email == Adresse && u.DeletedAt == null);

        admin.PasswordHash = hasher.Hash(nouveau);
        admin.MustChangePassword = false;

        await db.SaveChangesAsync();
    }

    /// <summary>Rejoue l'amorçage, comme le fait un redémarrage de l'API.</summary>
    private async Task ReamorcerAsync()
    {
        using var portee = fixture.Services.CreateScope();
        var amorceur = portee.ServiceProvider.GetRequiredService<AdminSeeder>();

        await amorceur.SeedAsync(CancellationToken.None);
    }
}
