namespace PartyPlan.IntegrationTests;

using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.SharedKernel.Contracts;
using Shouldly;
using Xunit;

/// <summary>
/// Lecture des notifications et préférences (§8.2, EF-NOT-07, EF-NOT-08).
/// <para>
/// Le cloisonnement y est plus large que celui des événements : chacun ne lit que ses
/// propres notifications, et aucun rôle plateforme n'y donne accès. Un administrateur qui
/// les lirait connaîtrait le contenu des soirées d'autrui par la bande (RG-ADM-01).
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class NotificationsLectureTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Chacun_ne_voit_que_ses_notifications()
    {
        var alex = await fixture.CompteAsync("Alex");
        var (eventId, jeton) = await alex.CreerEvenementAsync();

        var camille = await fixture.CompteAsync("Camille");
        await camille.RejoindreAsync(jeton);
        var compteCamille = await fixture.CompteDuMembreAsync(eventId, "Camille");

        await DeposerAsync(compteCamille, Guid.Parse(eventId), "Pour Camille");

        (await LireAsync(camille)).Items.ShouldContain(v => v.Title == "Pour Camille");
        (await LireAsync(alex)).Items.ShouldNotContain(v => v.Title == "Pour Camille");
    }

    [Fact]
    public async Task Un_appelant_anonyme_recoit_401()
    {
        using var anonyme = fixture.CreateClient();

        (await anonyme.GetAsync(new Uri("/v1/notifications", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Une_notification_encore_en_file_n_est_pas_rendue()
    {
        // Une ligne non partie n'a pas été reçue : l'afficher annoncerait un rappel
        // avant qu'il ne soit dû.
        var (client, compte, eventId) = await CompteAvecEvenementAsync();
        await DeposerAsync(compte, eventId, "Pas encore partie", partie: false);

        (await LireAsync(client)).Items.ShouldNotContain(v => v.Title == "Pas encore partie");
    }

    [Fact]
    public async Task Marquer_lu_est_idempotent_et_decompte_les_non_lues()
    {
        var (client, compte, eventId) = await CompteAvecEvenementAsync();
        await DeposerAsync(compte, eventId, "À lire");

        var avant = await LireAsync(client);
        avant.UnreadCount.ShouldBe(1);

        var id = avant.Items.Single(v => v.Title == "À lire").Id;

        (await client.PosterAsync($"/v1/notifications/{id}/read")).EnsureSuccessStatusCode();
        (await client.PosterAsync($"/v1/notifications/{id}/read")).EnsureSuccessStatusCode();

        (await LireAsync(client)).UnreadCount.ShouldBe(0);
    }

    [Fact]
    public async Task Marquer_lue_la_notification_d_un_autre_rend_404()
    {
        // 404 et non 403 : confirmer son existence renseignerait sur ce qui se passe
        // dans une soirée qui ne nous regarde pas.
        var (_, compte, eventId) = await CompteAvecEvenementAsync();
        await DeposerAsync(compte, eventId, "Privée");

        var proprietaire = await fixture.CompteAsync("Camille");
        var sienne = (await LireAsync(proprietaire)).Items;
        sienne.ShouldBeEmpty();

        var id = Guid.CreateVersion7();

        (await proprietaire.PosterAsync($"/v1/notifications/{id}/read"))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Tout_marquer_lu_vide_le_compteur()
    {
        var (client, compte, eventId) = await CompteAvecEvenementAsync();
        await DeposerAsync(compte, eventId, "Une");
        await DeposerAsync(compte, eventId, "Deux");

        (await client.PosterAsync("/v1/notifications/read-all")).EnsureSuccessStatusCode();

        (await LireAsync(client)).UnreadCount.ShouldBe(0);
    }

    [Fact]
    public async Task Une_limite_au_dela_du_plafond_est_refusee()
    {
        var (client, _, _) = await CompteAvecEvenementAsync();

        (await client.GetAsync(new Uri("/v1/notifications?limit=5000", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Les_sept_categories_sont_toujours_rendues()
    {
        // Une préférence absente vaut « activée » : l'écran doit pouvoir tout afficher
        // sans savoir lesquelles ont déjà été touchées.
        var (client, _, _) = await CompteAvecEvenementAsync();

        var preferences = await client.GetFromJsonAsync<List<PreferenceLue>>(
            "/v1/notifications/preferences");

        preferences!.Count.ShouldBe(NotificationCategories.All.Length);
        preferences.ShouldAllBe(p => p.PushEnabled);
    }

    [Fact]
    public async Task Une_categorie_se_desactive_et_se_relit()
    {
        var (client, _, _) = await CompteAvecEvenementAsync();

        (await client.PatchAsJsonAsync(
            "/v1/notifications/preferences",
            new
            {
                category = NotificationCategories.Activity,
                pushEnabled = false,
                emailEnabled = false,
            })).EnsureSuccessStatusCode();

        var preferences = await client.GetFromJsonAsync<List<PreferenceLue>>(
            "/v1/notifications/preferences");

        preferences!
            .Single(p => p.Category == NotificationCategories.Activity)
            .PushEnabled.ShouldBeFalse();
    }

    [Fact]
    public async Task Une_categorie_inconnue_est_refusee()
    {
        var (client, _, _) = await CompteAvecEvenementAsync();

        (await client.PatchAsJsonAsync(
            "/v1/notifications/preferences",
            new { category = "quelque.chose", pushEnabled = false, emailEnabled = false }))
            .StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task La_sourdine_se_pose_et_se_retire()
    {
        var (client, _, eventId) = await CompteAvecEvenementAsync();

        (await client.PutAsJsonAsync($"/v1/events/{eventId}/mute", new { muted = true }))
            .EnsureSuccessStatusCode();

        (await client.GetFromJsonAsync<bool>($"/v1/events/{eventId}/mute")).ShouldBeTrue();

        (await client.PutAsJsonAsync($"/v1/events/{eventId}/mute", new { muted = false }))
            .EnsureSuccessStatusCode();

        (await client.GetFromJsonAsync<bool>($"/v1/events/{eventId}/mute")).ShouldBeFalse();
    }

    [Fact]
    public async Task La_lecture_rend_la_valeur_resolue_et_dit_si_c_est_un_ecart()
    {
        // L'écran ne doit pas refaire la résolution : deux implémentations d'une même
        // règle finissent toujours par diverger.
        var (client, _, eventId) = await CompteAvecEvenementAsync();

        (await client.PatchAsJsonAsync(
            "/v1/notifications/preferences",
            new
            {
                category = NotificationCategories.DiscussionMessage,
                pushEnabled = false,
                emailEnabled = false,
            })).EnsureSuccessStatusCode();

        var vues = await LirePreferencesDeSoireeAsync(client, eventId);

        var vue = vues.Single(v => v.Category == NotificationCategories.DiscussionMessage);
        vue.Enabled.ShouldBeFalse();
        vue.EstUnEcart.ShouldBeFalse();
    }

    [Fact]
    public async Task Une_valeur_nulle_retire_l_ecart()
    {
        var (client, _, eventId) = await CompteAvecEvenementAsync();

        (await EcrirePreferenceDeSoireeAsync(
            client, eventId, NotificationCategories.DiscussionMessage, actif: true))
            .EnsureSuccessStatusCode();

        (await EcrirePreferenceDeSoireeAsync(
            client, eventId, NotificationCategories.DiscussionMessage, actif: null))
            .EnsureSuccessStatusCode();

        var vues = await LirePreferencesDeSoireeAsync(client, eventId);

        vues.Single(v => v.Category == NotificationCategories.DiscussionMessage)
            .EstUnEcart.ShouldBeFalse();
    }

    [Fact]
    public async Task Un_non_membre_recoit_404()
    {
        var (_, _, eventId) = await CompteAvecEvenementAsync();
        var etranger = await fixture.CompteAsync("Etranger");

        (await etranger.GetAsync(
            new Uri($"/v1/events/{eventId}/notifications/preferences", UriKind.Relative)))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    private static Task<HttpResponseMessage> EcrirePreferenceDeSoireeAsync(
        HttpClient client,
        Guid eventId,
        string categorie,
        bool? actif) =>
        client.PatchAsJsonAsync(
            $"/v1/events/{eventId}/notifications/preferences",
            new { category = categorie, enabled = actif });

    private static async Task<List<PreferenceDeSoireeLue>> LirePreferencesDeSoireeAsync(
        HttpClient client,
        Guid eventId)
    {
        var reponse = await client.GetAsync(
            new Uri($"/v1/events/{eventId}/notifications/preferences", UriKind.Relative));
        reponse.EnsureSuccessStatusCode();

        return (await reponse.Content.ReadFromJsonAsync<List<PreferenceDeSoireeLue>>(
            new JsonSerializerOptions(JsonSerializerDefaults.Web)))!;
    }

    private static async Task<PageLue> LireAsync(HttpClient client)
    {
        var reponse = await client.GetAsync(new Uri("/v1/notifications", UriKind.Relative));
        reponse.EnsureSuccessStatusCode();

        return (await reponse.Content.ReadFromJsonAsync<PageLue>(
            new JsonSerializerOptions(JsonSerializerDefaults.Web)))!;
    }

    private async Task<(HttpClient Client, Guid Compte, Guid EventId)>
        CompteAvecEvenementAsync()
    {
        var client = await fixture.CompteAsync("Camille");
        var (eventId, _) = await client.CreerEvenementAsync();

        return (client, await fixture.ProprietaireAsync(eventId), Guid.Parse(eventId));
    }

    private async Task DeposerAsync(
        Guid compte,
        Guid eventId,
        string titre,
        bool partie = true)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.Notifications.Add(new Notification
            {
                Id = Guid.CreateVersion7(),
                UserId = compte,
                EventId = eventId,
                Category = NotificationCategories.Activity,
                Title = titre,
                Body = "Corps",
                DeepLink = $"/events/{eventId}",
                ScheduledFor = DateTimeOffset.UtcNow.AddMinutes(-1),
                SentAt = partie ? DateTimeOffset.UtcNow : null,
                CreatedAt = DateTimeOffset.UtcNow,
                DedupKey = $"{eventId}:lecture:{compte}:{Guid.NewGuid():N}",
            });

            await db.SaveChangesAsync();
        });
    }

    private sealed record NotificationLue(Guid Id, string Title, bool Lue);

    private sealed record PageLue(
        IReadOnlyList<NotificationLue> Items,
        bool HasMore,
        int UnreadCount);

    private sealed record PreferenceLue(string Category, bool PushEnabled, bool EmailEnabled);

    private sealed record PreferenceDeSoireeLue(string Category, bool Enabled, bool EstUnEcart);
}
