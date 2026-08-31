namespace PartyPlan.IntegrationTests;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Passe d'envoi (EF-NOT-07, EF-NOT-08).
/// <para>
/// L'horodatage est le fil conducteur : une notification écartée pour de bon est
/// horodatée, une notification reportée ne l'est pas. Confondre les deux donne soit une
/// file relue indéfiniment, soit un avis perdu.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class EnvoiNotificationsTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    /// <summary>18 h à Paris.</summary>
    private static readonly DateTimeOffset SoireeAParis =
        new(2026, 9, 12, 16, 0, 0, TimeSpan.Zero);

    /// <summary>Compte et soirée partagés par les tests de résolution par soirée.</summary>
    private Guid _utilisateur;

    private Guid _evenement;

    public async Task InitializeAsync()
    {
        var jeu = await JeuAsync();
        _utilisateur = jeu.Compte;
        _evenement = jeu.EventId;
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Une_notification_due_part_et_est_horodatee()
    {
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, NotificationCategories.InvitationAnswer);

        await EnvoyerAsync(SoireeAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Une_categorie_desactivee_n_envoie_rien_mais_horodate()
    {
        // EF-NOT-07. Sans l'horodatage, la ligne serait réexaminée à chaque réveil,
        // indéfiniment, pour être écartée à chaque fois.
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, NotificationCategories.InvitationAnswer);
        await DesactiverAsync(jeu.Compte, NotificationCategories.InvitationAnswer);

        await EnvoyerAsync(SoireeAParis);

        // Horodatée sans être partie : l'appareil n'a rien reçu, mais la ligne ne sera
        // pas réexaminée.
        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Un_evenement_en_sourdine_n_envoie_rien_mais_horodate()
    {
        // EF-NOT-08.
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, NotificationCategories.InvitationAnswer);
        await MettreEnSourdineAsync(jeu.Compte, jeu.EventId);

        await EnvoyerAsync(SoireeAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Une_notification_part_a_23h()
    {
        var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage, heureLocale: 23);

        partis.ShouldBe(1);
    }

    [Fact]
    public async Task Un_rappel_part_aussi_a_23h()
    {
        // Plus aucune catégorie n'est reportée : le téléphone tranche, pas le serveur.
        var partis = await EnvoyerAsync(NotificationCategories.InvitationPending, heureLocale: 23);

        partis.ShouldBe(1);
    }

    [Fact]
    public async Task Sans_appareil_enregistre_la_ligne_est_tout_de_meme_horodatee()
    {
        // Sinon elle serait réessayée à chaque réveil pour un destinataire qui n'a pas
        // installé l'application.
        var jeu = await JeuAsync(avecAppareil: false);
        await EnfilerAsync(jeu, NotificationCategories.InvitationAnswer);

        await EnvoyerAsync(SoireeAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Une_notification_non_encore_due_reste_en_file()
    {
        var jeu = await JeuAsync();
        await EnfilerAsync(
            jeu,
            NotificationCategories.InvitationAnswer,
            prevuePour: SoireeAParis.AddHours(2));

        await EnvoyerAsync(SoireeAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldBeNull();
    }

    [Fact]
    public async Task Un_ecart_de_soiree_l_emporte_sur_la_preference_globale()
    {
        // Globalement coupée, autorisée sur cette soirée : la notification part.
        await PoserPreferenceGlobaleAsync(_utilisateur, NotificationCategories.DiscussionMessage, actif: false);
        await PoserEcartDeSoireeAsync(_utilisateur, _evenement, NotificationCategories.DiscussionMessage, actif: true);

        var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

        partis.ShouldBe(1);
    }

    [Fact]
    public async Task La_sourdine_l_emporte_sur_un_ecart_qui_autorise()
    {
        await PoserEcartDeSoireeAsync(_utilisateur, _evenement, NotificationCategories.DiscussionMessage, actif: true);
        await MettreEnSourdineAsync(_utilisateur, _evenement);

        var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

        partis.ShouldBe(0);
    }

    [Fact]
    public async Task Sans_ecart_la_preference_globale_s_applique()
    {
        await PoserPreferenceGlobaleAsync(_utilisateur, NotificationCategories.DiscussionMessage, actif: false);

        var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

        partis.ShouldBe(0);
    }

    [Fact]
    public async Task Sans_rien_de_pose_la_notification_part()
    {
        var partis = await EnvoyerAsync(NotificationCategories.DiscussionMessage);

        partis.ShouldBe(1);
    }

    private async Task PoserEcartDeSoireeAsync(
        Guid utilisateur,
        Guid evenement,
        string categorie,
        bool actif)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.EventNotificationPreferences.Add(new EventNotificationPreference
            {
                Id = Guid.CreateVersion7(),
                UserId = utilisateur,
                EventId = evenement,
                Category = categorie,
                Enabled = actif,
                UpdatedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    private async Task PoserPreferenceGlobaleAsync(Guid utilisateur, string categorie, bool actif)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.NotificationPreferences.Add(new NotificationPreference
            {
                Id = Guid.CreateVersion7(),
                UserId = utilisateur,
                Category = categorie,
                PushEnabled = actif,
                EmailEnabled = actif,
                UpdatedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    /// <summary>
    /// Enfile une notification pour la soirée partagée du test, puis déclenche la passe
    /// d'envoi à l'heure locale (Paris) demandée. Renvoie le nombre de notifications
    /// réellement parties pour <b>cette</b> notification.
    /// <para>
    /// La passe elle-même est globale et la collection de tests partage une seule base :
    /// un due laissé en file par une autre classe se mêlerait à notre propre compte si on
    /// le lisait tel quel. On ne peut pas non plus isoler la mesure en comparant
    /// l'horodatage avant/après sur les seules lignes de l'événement (le motif de
    /// <c>NotificationsDiscussionTests</c>) : une notification écartée est, elle aussi,
    /// horodatée sans partir (EF-NOT-07/08), donc un simple diff sur <c>SentAt</c> ne
    /// distinguerait pas un envoi réel d'un rejet. La première passe vide plutôt tout due
    /// éventuel laissé par une autre classe ; comme la collection s'exécute en séquence,
    /// seule notre notification, enfilée juste après, reste due pour la seconde passe.
    /// </para>
    /// </summary>
    private async Task<int> EnvoyerAsync(string categorie, int heureLocale = 18)
    {
        var instant = new DateTimeOffset(2026, 9, 12, heureLocale - 2, 0, 0, TimeSpan.Zero);

        // Paris est en UTC+2 en septembre (heure d'été).
        await EnvoyerAsync(instant);

        await EnfilerAsync(new Jeu(_utilisateur, _evenement), categorie);

        return await EnvoyerAsync(instant);
    }

    private async Task<int> EnvoyerAsync(DateTimeOffset instant)
    {
        // Attendu dans la portée, et non renvoyé depuis elle : rendre la tâche libérerait
        // la portée — donc le DbContext — avant que la requête ne soit lue.
        using var portee = fixture.Services.CreateScope();

        return await portee.ServiceProvider
            .GetRequiredService<IEnvoiNotifications>()
            .EnvoyerLesDuesAsync(instant, CancellationToken.None);
    }

    private async Task EnfilerAsync(
        Jeu jeu,
        string categorie,
        DateTimeOffset? prevuePour = null)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.Notifications.Add(new Notification
            {
                Id = Guid.CreateVersion7(),
                UserId = jeu.Compte,
                EventId = jeu.EventId,
                Category = categorie,
                Title = "Titre",
                Body = "Corps",
                DeepLink = $"/events/{jeu.EventId}",
                ScheduledFor = prevuePour ?? SoireeAParis.AddMinutes(-1),
                CreatedAt = SoireeAParis.AddMinutes(-1),
                DedupKey = $"{jeu.EventId}:{categorie}:{jeu.Compte}:{Guid.NewGuid():N}",
            });

            await db.SaveChangesAsync();
        });
    }

    private async Task DesactiverAsync(Guid compte, string categorie)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.NotificationPreferences.Add(new NotificationPreference
            {
                Id = Guid.CreateVersion7(),
                UserId = compte,
                Category = categorie,
                PushEnabled = false,
                EmailEnabled = false,
                UpdatedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    private async Task MettreEnSourdineAsync(Guid compte, Guid eventId)
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            db.EventMuteSettings.Add(new EventMuteSetting
            {
                Id = Guid.CreateVersion7(),
                UserId = compte,
                EventId = eventId,
                MutedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    private async Task<List<Notification>> LireAsync(Guid eventId)
    {
        List<Notification> lignes = [];

        await fixture.WithDatabaseAsync(async db =>
            lignes = await db.Notifications
                .Where(n => n.EventId == eventId)
                .ToListAsync());

        return lignes;
    }

    private async Task<Jeu> JeuAsync(bool avecAppareil = true)
    {
        var compte = Guid.CreateVersion7();
        var eventId = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new User
            {
                Id = compte,
                Email = $"envoi-{compte:N}@partyplan.test",
                DisplayName = "Camille",
                PasswordHash = "x",
                Timezone = "Europe/Paris",
                CreatedAt = DateTimeOffset.UtcNow,
            });

            db.Events.Add(new Event
            {
                Id = eventId,
                Name = "Soirée d'envoi",
                StartsAt = SoireeAParis.AddDays(3),
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = compte,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = Guid.CreateVersion7(),
                EventId = eventId,
                UserId = compte,
                DisplayName = "Camille",
                Role = EventMemberRole.Owner,
                Status = EventMemberStatus.Going,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            if (avecAppareil)
            {
                db.PushDevices.Add(new PushDevice
                {
                    Id = Guid.CreateVersion7(),
                    UserId = compte,
                    Token = $"jeton-{compte:N}",
                    Platform = "android",
                    CreatedAt = DateTimeOffset.UtcNow,
                    LastSeenAt = DateTimeOffset.UtcNow,
                });
            }

            await db.SaveChangesAsync();
        });

        return new Jeu(compte, eventId);
    }

    private sealed record Jeu(Guid Compte, Guid EventId);
}
