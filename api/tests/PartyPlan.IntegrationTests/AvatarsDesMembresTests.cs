namespace PartyPlan.IntegrationTests;

using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// La photo de profil suit son auteur partout où il apparaît.
/// <para>
/// Le champ existait dans les vues depuis le début mais était câblé à <c>null</c> : les
/// écrans affichaient un rond de couleur pour tout le monde, y compris pour les
/// personnes ayant déposé une photo. Le défaut se voyait à l'usage et nulle part
/// ailleurs — aucune requête n'échouait.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class AvatarsDesMembresTests(PartyPlanApiFixture fixture)
{
    private const string MotDePasse = "Trombone-Nuage-42x";
    private const string Photo = "/media/avatars/essai.webp";

    [Fact]
    public async Task La_liste_des_membres_porte_la_photo_de_chacun()
    {
        var (client, evenement) = await SoireeAvecPhotoAsync();

        var membres = await client.GetFromJsonAsync<JsonDocument>(
            new Uri($"/v1/events/{evenement}/members", UriKind.Relative));

        var moi = membres!.RootElement.EnumerateArray()
            .First(m => m.GetProperty("isMe").GetBoolean());

        moi.GetProperty("avatarUrl").GetString().ShouldBe(Photo);
    }

    [Fact]
    public async Task Un_message_de_discussion_porte_la_photo_de_son_auteur()
    {
        var (client, evenement) = await SoireeAvecPhotoAsync();

        var envoi = new HttpRequestMessage(
            HttpMethod.Post,
            new Uri($"/v1/events/{evenement}/messages", UriKind.Relative))
        {
            Content = JsonContent.Create(new { body = "On apporte quoi ?" }),
        };
        envoi.Headers.Add("Idempotency-Key", Guid.CreateVersion7().ToString());

        var reponse = await client.SendAsync(envoi);
        reponse.EnsureSuccessStatusCode();

        var message = await reponse.Content.ReadFromJsonAsync<JsonDocument>();

        message!.RootElement.GetProperty("authorAvatarUrl").GetString()
            .ShouldBe(Photo);
    }

    /// <summary>Un compte muni d'une photo, propriétaire d'une soirée.</summary>
    private async Task<(HttpClient Client, Guid Evenement)> SoireeAvecPhotoAsync()
    {
        using var anonyme = fixture.CreateClient();

        var courriel = $"avatar-{Guid.CreateVersion7():N}@partyplan.test";

        var inscription = await anonyme.PostAsJsonAsync(
            new Uri("/v1/auth/register", UriKind.Relative),
            new { email = courriel, password = MotDePasse, displayName = "Maxence" });

        inscription.EnsureSuccessStatusCode();

        var client = fixture.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            (await inscription.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("accessToken").GetString());

        // La photo est posée directement en base : l'envoi réel passe par SkiaSharp, qui
        // n'a rien à voir avec ce que ce test vérifie.
        await fixture.WithDatabaseAsync(async db =>
        {
            var compte = await db.Users.SingleAsync(u => u.Email == courriel);
            compte.AvatarUrl = Photo;
            await db.SaveChangesAsync();
        });

        var creation = await EvenementsTests.CreerBrutAsync(client, new
        {
            name = "Avatars",
            startsAt = DateTimeOffset.UtcNow.AddDays(3),
        });

        creation.EnsureSuccessStatusCode();

        return (
            client,
            (await creation.Content.ReadFromJsonAsync<JsonDocument>())!
                .RootElement.GetProperty("id").GetGuid());
    }
}
