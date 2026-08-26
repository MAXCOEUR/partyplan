namespace PartyPlan.IntegrationTests;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PartyPlan.Infrastructure.Persistence;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Events.Domain;
using PartyPlan.Modules.Users.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Enums;
using Shouldly;
using Xunit;

/// <summary>
/// Contrat d'écriture du fil d'activité (EF-FIL-01).
/// <para>
/// La garantie éprouvée ici est celle de la transaction : l'entrée vit ou meurt avec
/// l'action métier qui l'a produite. Sans elle, le fil cesse d'être la trace de
/// référence en cas de litige sur les montants (RG-FIL-02) — il devient un journal
/// approximatif, ce qui est pire qu'aucun journal.
/// </para>
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class JournalActiviteTests(PartyPlanApiFixture fixture) : IAsyncLifetime
{
    private Guid _eventId;
    private Guid _memberId;

    public async Task InitializeAsync()
    {
        _eventId = Guid.CreateVersion7();
        _memberId = Guid.CreateVersion7();
        var userId = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.Users.Add(new User
            {
                Id = userId,
                Email = $"journal-{userId:N}@partyplan.test",
                DisplayName = "Camille",
                PasswordHash = "x",
                CreatedAt = DateTimeOffset.UtcNow,
            });

            db.Events.Add(new Event
            {
                Id = _eventId,
                Name = "Soirée du journal",
                StartsAt = DateTimeOffset.UtcNow.AddDays(3),
                InviteToken = Guid.NewGuid().ToString("N"),
                ShortCode = _eventId.ToString("N")[..12].ToUpperInvariant(),
                CreatedByUserId = userId,
            });

            db.EventMembers.Add(new EventMember
            {
                Id = _memberId,
                EventId = _eventId,
                UserId = userId,
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
    public async Task Consigner_puis_SaveChanges_ecrit_la_ligne()
    {
        await DansUnePorteeAsync(async (journal, db) =>
        {
            journal.Consigner(
                _eventId,
                _memberId,
                "Camille",
                ActivityKinds.ItemCreated,
                new { libelle = "Glaçons" });

            await db.SaveChangesAsync();
        });

        var ligne = (await LireAsync()).ShouldHaveSingleItem();
        ligne.Kind.ShouldBe(ActivityKinds.ItemCreated);
        ligne.ActorName.ShouldBe("Camille");
        ligne.MemberId.ShouldBe(_memberId);
        // Sans échappement agressif : « Glaçons » stocké en ç serait illisible en
        // base, où l'on relit ce fil en cas de litige.
        ligne.Payload.ShouldNotBeNull().ShouldContain("Glaçons");
    }

    [Fact]
    public async Task Consigner_sans_SaveChanges_n_ecrit_rien()
    {
        // Le test qui compte. Si Consigner sauvegardait lui-même, la garantie de
        // transaction tomberait sans qu'aucun autre test ne rougisse.
        await DansUnePorteeAsync((journal, _) =>
        {
            journal.Consigner(_eventId, _memberId, "Camille", ActivityKinds.ItemCreated);
            return Task.CompletedTask;
        });

        (await LireAsync()).ShouldBeEmpty();
    }

    [Fact]
    public async Task Une_transaction_annulee_ne_laisse_aucune_ligne()
    {
        await DansUnePorteeAsync(async (journal, db) =>
        {
            // La stratégie d'exécution avec reprise interdit d'ouvrir une transaction à
            // la main hors d'elle. C'est aussi ce qui garantit, en production, qu'une
            // action métier tient dans un seul SaveChangesAsync : personne ne peut
            // découper l'écriture en deux transactions sans passer par ici.
            await db.Database.CreateExecutionStrategy().ExecuteAsync(async () =>
            {
                await using var transaction = await db.Database.BeginTransactionAsync();

                journal.Consigner(
                    _eventId,
                    _memberId,
                    "Camille",
                    ActivityKinds.ExpenseCreated,
                    new { libelle = "Courses", montant = 62.40m });

                await db.SaveChangesAsync();
                await transaction.RollbackAsync();
            });
        });

        (await LireAsync()).ShouldBeEmpty();
    }

    [Fact]
    public async Task Le_payload_est_nul_quand_aucune_donnee_n_est_fournie()
    {
        await DansUnePorteeAsync(async (journal, db) =>
        {
            journal.Consigner(_eventId, _memberId, "Camille", ActivityKinds.MemberJoined);
            await db.SaveChangesAsync();
        });

        (await LireAsync()).ShouldHaveSingleItem().Payload.ShouldBeNull();
    }

    [Fact]
    public async Task La_base_refuse_de_modifier_ou_de_supprimer_une_ligne()
    {
        // NF-SEC-08, règle 4. Le déclencheur protège même une écriture faite hors de
        // l'application.
        await DansUnePorteeAsync(async (journal, db) =>
        {
            journal.Consigner(_eventId, _memberId, "Camille", ActivityKinds.MemberJoined);
            await db.SaveChangesAsync();
        });

        await fixture.WithDatabaseAsync(async db =>
        {
            var modification = await Should.ThrowAsync<Npgsql.PostgresException>(async () =>
                await db.Database.ExecuteSqlRawAsync(
                    "UPDATE activity_entries SET actor_name = 'falsifie' WHERE event_id = {0}",
                    _eventId));
            modification.MessageText.ShouldContain("ajout seul");

            var suppression = await Should.ThrowAsync<Npgsql.PostgresException>(async () =>
                await db.Database.ExecuteSqlRawAsync(
                    "DELETE FROM activity_entries WHERE event_id = {0}",
                    _eventId));
            suppression.MessageText.ShouldContain("ajout seul");
        });
    }

    /// <summary>
    /// Exécute une action dans une portée d'injection unique, afin que le journal et le
    /// contexte partagent la même unité de travail — c'est précisément ce que la
    /// garantie de transaction suppose.
    /// </summary>
    private async Task DansUnePorteeAsync(Func<IJournalActivite, PartyPlanDbContext, Task> action)
    {
        using var portee = fixture.Services.CreateScope();
        var journal = portee.ServiceProvider.GetRequiredService<IJournalActivite>();
        var db = portee.ServiceProvider.GetRequiredService<PartyPlanDbContext>();

        await action(journal, db);
    }

    /// <summary>
    /// Lit sans filtre de cloisonnement : aucun périmètre n'est amorcé hors d'une
    /// requête HTTP, et le filtre global renverrait donc systématiquement zéro ligne.
    /// </summary>
    private async Task<List<ActivityEntry>> LireAsync()
    {
        List<ActivityEntry> lignes = [];

        await fixture.WithDatabaseAsync(async db =>
            lignes = await db.ActivityEntries
                .IgnoreQueryFilters()
                .Where(a => a.EventId == _eventId)
                .ToListAsync());

        return lignes;
    }
}
