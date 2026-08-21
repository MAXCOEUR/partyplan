using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PartyPlan.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class RepereDeLecture : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "message_reads",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    event_id = table.Column<Guid>(type: "uuid", nullable: false),
                    member_id = table.Column<Guid>(type: "uuid", nullable: false),
                    last_read_message_id = table.Column<Guid>(type: "uuid", nullable: false),
                    last_read_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_message_reads", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "ix_message_reads_event_id_member_id",
                table: "message_reads",
                columns: new[] { "event_id", "member_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "message_reads");
        }
    }
}
