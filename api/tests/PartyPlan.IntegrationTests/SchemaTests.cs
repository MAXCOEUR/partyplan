namespace PartyPlan.IntegrationTests;

using Microsoft.EntityFrameworkCore;
using PartyPlan.IntegrationTests.Infrastructure;
using Shouldly;
using Xunit;

/// <summary>
/// Garanties portées par le schéma lui-même. Une règle vérifiée uniquement par le code
/// applicatif tombe dès qu'une écriture passe par un autre chemin.
/// </summary>
[Collection(ApiTestSuite.Name)]
public sealed class SchemaTests(PartyPlanApiFixture fixture)
{
    [Fact]
    public async Task Aucune_migration_ne_reste_en_attente()
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            var pending = await db.Database.GetPendingMigrationsAsync();
            pending.ShouldBeEmpty();
        });
    }

    [Fact]
    public async Task Les_montants_sont_stockes_en_numerique_exact()
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            var types = await db.Database
                .SqlQuery<string>($"""
                    SELECT table_name || '.' || column_name || ':' || data_type
                           || '(' || numeric_precision || ',' || numeric_scale || ')' AS "Value"
                    FROM information_schema.columns
                    WHERE column_name IN ('amount', 'actual_price', 'estimated_price')
                    ORDER BY 1
                    """)
                .ToListAsync();

            types.ShouldNotBeEmpty();

            // §6.1 : jamais de type flottant sur un montant.
            foreach (var type in types)
            {
                type.ShouldContain("numeric(10,2)");
            }
        });
    }

    [Fact]
    public async Task Un_montant_de_depense_negatif_est_refuse_par_la_base()
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            var exception = await Should.ThrowAsync<Npgsql.PostgresException>(async () =>
                await db.Database.ExecuteSqlRawAsync(
                    """
                    INSERT INTO expenses (id, event_id, label, amount, paid_by_member_id,
                                          spent_at, created_by_member_id, created_at, updated_at)
                    VALUES (gen_random_uuid(), gen_random_uuid(), 'test', -1,
                            gen_random_uuid(), now(), gen_random_uuid(), now(), now())
                    """));

            // La contrainte de plage se déclenche avant la clé étrangère.
            exception.SqlState.ShouldBeOneOf("23514", "23503");
        });
    }

    [Fact]
    public async Task Le_journal_d_audit_n_a_aucune_cle_etrangere_vers_les_comptes()
    {
        await fixture.WithDatabaseAsync(async db =>
        {
            // RG-ADM-06 : le journal doit survivre à la suppression des comptes cités.
            var count = await db.Database
                .SqlQuery<int>($"""
                    SELECT COUNT(*)::int AS "Value"
                    FROM pg_constraint
                    WHERE conrelid = 'admin_audit_entries'::regclass AND contype = 'f'
                    """)
                .SingleAsync();

            count.ShouldBe(0);
        });
    }
}
