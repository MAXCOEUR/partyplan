namespace PartyPlan.IntegrationTests;

using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using PartyPlan.Modules.Administration.Domain;
using PartyPlan.SharedKernel.Contracts;
using PartyPlan.SharedKernel.Errors;
using Shouldly;
using Xunit;

/// <summary>
/// Immuabilité du journal d'audit (RG-ADM-06, NF-SEC-08). Deux barrières sont
/// vérifiées : le garde applicatif du DbContext, et le déclencheur de la base — ce
/// dernier protège même contre une écriture faite hors de l'application.
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class AppendOnlyTablesTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Le_contexte_refuse_de_modifier_une_entree_d_audit()
    {
        var id = await InsertEntryAsync();

        await Should.ThrowAsync<ModuleBoundaryException>(async () =>
            await fixture.WithDatabaseAsync(async db =>
            {
                var entry = await db.AdminAuditEntries.SingleAsync(e => e.Id == id);
                db.Entry(entry).Property(e => e.Action).CurrentValue = "falsifie";
                db.Entry(entry).State = EntityState.Modified;
                await db.SaveChangesAsync();
            }));
    }

    [Fact]
    public async Task Le_contexte_refuse_de_supprimer_une_entree_d_audit()
    {
        var id = await InsertEntryAsync();

        await Should.ThrowAsync<ModuleBoundaryException>(async () =>
            await fixture.WithDatabaseAsync(async db =>
            {
                var entry = await db.AdminAuditEntries.SingleAsync(e => e.Id == id);
                db.AdminAuditEntries.Remove(entry);
                await db.SaveChangesAsync();
            }));
    }

    [Fact]
    public async Task La_base_refuse_un_update_direct()
    {
        var id = await InsertEntryAsync();

        await fixture.WithDatabaseAsync(async db =>
        {
            var exception = await Should.ThrowAsync<Npgsql.PostgresException>(async () =>
                await db.Database.ExecuteSqlRawAsync(
                    "UPDATE admin_audit_entries SET action = 'falsifie' WHERE id = {0}", id));

            exception.MessageText.ShouldContain("ajout seul");
        });
    }

    [Fact]
    public async Task La_base_refuse_un_truncate()
    {
        await InsertEntryAsync();

        await fixture.WithDatabaseAsync(async db =>
        {
            // TRUNCATE contourne les déclencheurs par ligne : c'est pourquoi un
            // déclencheur au niveau instruction est également posé.
            var exception = await Should.ThrowAsync<Npgsql.PostgresException>(async () =>
                await db.Database.ExecuteSqlRawAsync("TRUNCATE admin_audit_entries"));

            exception.MessageText.ShouldContain("ajout seul");
        });
    }

    private async Task<Guid> InsertEntryAsync()
    {
        var id = Guid.CreateVersion7();

        await fixture.WithDatabaseAsync(async db =>
        {
            db.AdminAuditEntries.Add(new AdminAuditEntry
            {
                Id = id,
                ActorUserId = Guid.CreateVersion7(),
                ActorEmail = "admin@partyplan.test",
                Action = AdminAuditActions.AdminSeeded,
                CreatedAt = DateTimeOffset.UtcNow,
            });

            await db.SaveChangesAsync();
        });

        return id;
    }
}
