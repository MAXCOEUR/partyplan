namespace PartyPlan.IntegrationTests;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Notifications.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Mise en file des notifications (§5.12).
/// <para>
/// Deux garanties y sont éprouvées : la ligne vit ou meurt avec l'action qui l'a
/// produite, et une clé de déduplication ne peut pas exister deux fois. La seconde est
/// ce qui rend le balayage rejouable — sans elle, un rappel J-3 partirait vingt fois par
/// heure.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class FileNotificationsTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    private Guid _eventId;
    private Guid _userId;

    public async Task InitializeAsync()
    {
        _eventId = Guid.CreateVersion7();
        _userId = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new User
            {
                Id = _userId,
                Email = $"file-{_userId:N}@partyplan.test",
                DisplayName = "Camille",
                PasswordHash = "x",
                CreatedAt = DateTimeOffset.UtcNow,
            });

            db.Events.Add(new Event
            {
                Id = _eventId,
                Name = "Soirée de la file",
                StartsAt = DateTimeOffset.UtcNow.AddDays(3),
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = _eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = _userId,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = Guid.CreateVersion7(),
                EventId = _eventId,
                UserId = _userId,
                DisplayName = "Camille",
                Role = EventMemberRole.Owner,
                Status = EventMemberStatus.Going,
                JoinedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });
    }

    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Enfiler_puis_SaveChanges_ecrit_la_ligne()
    {
        var cle = $"{_eventId}:invitation.answer:{_userId}:essai";

        await DansUnePorteeAsync(async (file, db) =>
        {
            file.Enfiler(Notification(cle));
            await db.SaveChangesAsync();
        });

        var ligne = (await LireAsync()).ShouldHaveSingleItem();
        ligne.DedupKey.ShouldBe(cle);
        ligne.SentAt.ShouldBeNull();
    }

    [Fact]
    public async Task Enfiler_sans_SaveChanges_n_ecrit_rien()
    {
        // Même garantie que le fil d'activité : la notification appartient à la
        // transaction de l'action. Une réponse qui échoue ne doit pas laisser partir un
        // avis annonçant une réponse qui n'a pas eu lieu.
        await DansUnePorteeAsync((file, _) =>
        {
            file.Enfiler(Notification($"{_eventId}:invitation.answer:{_userId}:sans-save"));
            return Task.CompletedTask;
        });

        (await LireAsync()).ShouldBeEmpty();
    }

    [Fact]
    public async Task Une_cle_deja_enfilee_dans_la_meme_portee_n_ajoute_rien()
    {
        var cle = $"{_eventId}:invitation.pending:{_userId}:j-3";

        await DansUnePorteeAsync(async (file, db) =>
        {
            file.Enfiler(Notification(cle));
            file.Enfiler(Notification(cle));
            await db.SaveChangesAsync();
        });

        (await LireAsync()).Count.ShouldBe(1);
    }

    [Fact]
    public async Task Une_cle_deja_en_base_n_ajoute_rien_et_ne_leve_pas()
    {
        // Le cas normal d'un balayage rejoué, pas une erreur : la planification doit
        // pouvoir tourner toutes les minutes sans conséquence.
        var cle = $"{_eventId}:invitation.pending:{_userId}:j-1";

        await DansUnePorteeAsync(async (file, db) =>
        {
            file.Enfiler(Notification(cle));
            await db.SaveChangesAsync();
        });

        await DansUnePorteeAsync(async (file, db) =>
        {
            file.Enfiler(Notification(cle));
            await db.SaveChangesAsync();
        });

        (await LireAsync()).Count.ShouldBe(1);
    }

    [Fact]
    public async Task La_base_refuse_deux_lignes_de_meme_cle()
    {
        // La contrainte est en base et non dans l'application : vérifier puis écrire
        // laisserait ouverte exactement la fenêtre qu'un balayage à la minute exploite.
        var cle = $"{_eventId}:event.changed:{_userId}:contrainte";

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Notifications.Add(Entree(cle));
            await db.SaveChangesAsync();
        });

        await Should.ThrowAsync<DbUpdateException>(async () =>
            await fixture.WithDatabaseAsync(async db =>
            {
                db.Notifications.Add(Entree(cle));
                await db.SaveChangesAsync();
            }));
    }

    private NotificationAEnvoyer Notification(string cle) => new(
        _userId,
        _eventId,
        NotificationCategories.InvitationAnswer,
        "Camille a répondu",
        "Camille vient à la soirée.",
        $"/events/{_eventId}",
        DateTimeOffset.UtcNow,
        cle);

    private Notification Entree(string cle) => new()
    {
        Id = Guid.CreateVersion7(),
        UserId = _userId,
        EventId = _eventId,
        Category = NotificationCategories.EventChanged,
        Title = "Titre",
        Body = "Corps",
        ScheduledFor = DateTimeOffset.UtcNow,
        CreatedAt = DateTimeOffset.UtcNow,
        DedupKey = cle,
    };

    private async Task DansUnePorteeAsync(
        Func<IFileNotifications, PartyPlanDbContext, Task> action)
    {
        using var portee = fixture.Services.CreateScope();
        var file = portee.ServiceProvider.GetRequiredService<IFileNotifications>();
        var db = portee.ServiceProvider.GetRequiredService<PartyPlanDbContext>();

        await action(file, db);
    }

    private async Task<List<Notification>> LireAsync()
    {
        List<Notification> lignes = [];

        await fixture.WithDatabaseAsync(async db =>
            lignes = await db.Notifications
                .Where(n => n.EventId == _eventId)
                .ToListAsync());

        return lignes;
    }
}
