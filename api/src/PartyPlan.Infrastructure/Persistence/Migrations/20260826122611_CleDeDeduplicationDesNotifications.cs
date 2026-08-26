using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PartyPlan.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CleDeDeduplicationDesNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "dedup_key",
                table: "notifications",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "ix_notifications_dedup_key",
                table: "notifications",
                column: "dedup_key",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_notifications_dedup_key",
                table: "notifications");

            migrationBuilder.DropColumn(
                name: "dedup_key",
                table: "notifications");
        }
    }
}
