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
/// Passe d'envoi (RG-NOT-01, EF-NOT-07, EF-NOT-08).
/// <para>
/// L'horodatage est le fil conducteur : une notification écartée pour de bon est
/// horodatée, une notification reportée ne l'est pas. Confondre les deux donne soit une
/// file relue indéfiniment, soit un avis perdu.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class EnvoiNotificationsTests(PartyPlanApiFixture fixture)
{
    /// <summary>18 h à Paris : hors plage de silence. 4 h à Auckland : dedans.</summary>
    private static readonly DateTimeOffset SoireeAParis =
        new(2026, 9, 12, 16, 0, 0, TimeSpan.Zero);

    /// <summary>23 h à Paris : dans la plage de silence.</summary>
    private static readonly DateTimeOffset NuitAParis =
        new(2026, 9, 12, 21, 0, 0, TimeSpan.Zero);

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
    public async Task La_plage_de_silence_reporte_sans_horodater()
    {
        // RG-NOT-01. Reportée, pas abandonnée : c'est toute la différence.
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, NotificationCategories.InvitationAnswer);

        await EnvoyerAsync(NuitAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldBeNull();

        // Le lendemain matin, elle part.
        await EnvoyerAsync(NuitAParis.AddHours(11));

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Le_rappel_de_debut_traverse_la_plage_de_silence()
    {
        // L'exception écrite dans RG-NOT-01 : une soirée qui commence à 23 h se rappelle
        // à 21 h, et se taire alors rendrait le rappel inutile quand il sert.
        var jeu = await JeuAsync();
        await EnfilerAsync(jeu, NotificationCategories.EventStartingSoon);

        await EnvoyerAsync(NuitAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Deux_fuseaux_ne_sont_pas_en_heure_creuse_au_meme_instant()
    {
        // C'est tout l'objet de « heure locale du destinataire ». À 16 h UTC il est 18 h
        // à Paris et 4 h du matin le lendemain à Auckland.
        var paris = await JeuAsync(fuseau: "Europe/Paris");
        var auckland = await JeuAsync(fuseau: "Pacific/Auckland");

        await EnfilerAsync(paris, NotificationCategories.InvitationAnswer);
        await EnfilerAsync(auckland, NotificationCategories.InvitationAnswer);

        await EnvoyerAsync(SoireeAParis);

        (await LireAsync(paris.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
        (await LireAsync(auckland.EventId)).ShouldHaveSingleItem().SentAt.ShouldBeNull();
    }

    [Fact]
    public async Task Un_fuseau_inconnu_ne_prive_pas_de_notification()
    {
        // Ne jamais notifier vaut moins bien que notifier à une heure approchante.
        var jeu = await JeuAsync(fuseau: "Mars/Olympus_Mons");
        await EnfilerAsync(jeu, NotificationCategories.InvitationAnswer);

        await EnvoyerAsync(SoireeAParis);

        (await LireAsync(jeu.EventId)).ShouldHaveSingleItem().SentAt.ShouldNotBeNull();
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

    private async Task<Jeu> JeuAsync(
        string fuseau = "Europe/Paris",
        bool avecAppareil = true)
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
                Timezone = fuseau,
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
