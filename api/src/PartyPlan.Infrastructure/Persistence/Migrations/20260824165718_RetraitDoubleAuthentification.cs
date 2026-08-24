using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PartyPlan.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// Retrait de la double authentification — ADR 0007.
    /// <para>
    /// Les secrets et les codes de secours sont détruits, et non conservés « au cas
    /// où » : plus aucun code ne les lit, ce qui en fait des données personnelles
    /// gardées sans finalité. <c>Down</c> rétablit la structure, jamais le contenu — un
    /// compte qui avait activé la double authentification devra se réenrôler si la
    /// fonctionnalité revient un jour.
    /// </para>
    /// </summary>
    public partial class RetraitDoubleAuthentification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "totp_recovery_codes");

            migrationBuilder.DropColumn(
                name: "totp_enabled_at",
                table: "users");

            migrationBuilder.DropColumn(
                name: "totp_secret_encrypted",
                table: "users");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "totp_enabled_at",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "totp_secret_encrypted",
                table: "users",
                type: "character varying(512)",
                maxLength: 512,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "totp_recovery_codes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    code_hash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    used_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_totp_recovery_codes", x => x.id);
                    table.ForeignKey(
                        name: "fk_totp_recovery_codes_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_totp_recovery_codes_code_hash",
                table: "totp_recovery_codes",
                column: "code_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_totp_recovery_codes_user_id_used_at",
                table: "totp_recovery_codes",
                columns: new[] { "user_id", "used_at" });
        }
    }
}
