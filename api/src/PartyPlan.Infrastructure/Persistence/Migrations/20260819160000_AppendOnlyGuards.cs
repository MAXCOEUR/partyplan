namespace PartyPlan.Infrastructure.Persistence.Migrations;

using Microsoft.EntityFrameworkCore.Migrations;

/// <summary>
/// Interdit en base la modification et la suppression des tables en ajout seul
/// (NF-SEC-08, RG-ADM-06, RG-FIL-02).
/// <para>
/// Un déclencheur est retenu plutôt qu'un simple retrait de droits : le propriétaire
/// d'une table contourne les <c>GRANT</c>, si bien qu'une révocation seule ne protégerait
/// pas contre une écriture faite avec le compte de migration. Le déclencheur s'applique
/// à tout le monde, sans exception.
/// </para>
/// </summary>
public sealed partial class AppendOnlyGuards : Migration
{
    private static readonly string[] AppendOnlyTables =
    [
        "admin_audit_entries",
        "activity_entries",
        "expense_revisions",
    ];

    protected override void Up(MigrationBuilder migrationBuilder)
    {
        ArgumentNullException.ThrowIfNull(migrationBuilder);

        migrationBuilder.Sql(
            """
            CREATE OR REPLACE FUNCTION partyplan_refuse_append_only()
            RETURNS trigger
            LANGUAGE plpgsql
            AS $$
            BEGIN
                RAISE EXCEPTION
                    'La table % est en ajout seul : ni UPDATE ni DELETE ne sont permis (NF-SEC-08).',
                    TG_TABLE_NAME
                    USING ERRCODE = 'restrict_violation';
            END;
            $$;
            """);

        foreach (var table in AppendOnlyTables)
        {
            migrationBuilder.Sql(
                $"""
                CREATE TRIGGER trg_{table}_append_only
                BEFORE UPDATE OR DELETE ON {table}
                FOR EACH ROW EXECUTE FUNCTION partyplan_refuse_append_only();
                """);

            // TRUNCATE ne déclenche pas les déclencheurs par ligne : sans ce second
            // déclencheur au niveau instruction, une seule commande viderait le journal.
            migrationBuilder.Sql(
                $"""
                CREATE TRIGGER trg_{table}_no_truncate
                BEFORE TRUNCATE ON {table}
                FOR EACH STATEMENT EXECUTE FUNCTION partyplan_refuse_append_only();
                """);
        }
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        ArgumentNullException.ThrowIfNull(migrationBuilder);

        foreach (var table in AppendOnlyTables)
        {
            migrationBuilder.Sql($"DROP TRIGGER IF EXISTS trg_{table}_append_only ON {table};");
            migrationBuilder.Sql($"DROP TRIGGER IF EXISTS trg_{table}_no_truncate ON {table};");
        }

        migrationBuilder.Sql("DROP FUNCTION IF EXISTS partyplan_refuse_append_only();");
    }
}
