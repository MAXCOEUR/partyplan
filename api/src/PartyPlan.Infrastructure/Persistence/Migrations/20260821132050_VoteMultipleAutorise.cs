using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PartyPlan.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class VoteMultipleAutorise : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_poll_votes_poll_id_member_id",
                table: "poll_votes");

            migrationBuilder.CreateIndex(
                name: "ix_poll_votes_poll_id_member_id_option_id",
                table: "poll_votes",
                columns: new[] { "poll_id", "member_id", "option_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "ix_poll_votes_poll_id_member_id_option_id",
                table: "poll_votes");

            migrationBuilder.CreateIndex(
                name: "ix_poll_votes_poll_id_member_id",
                table: "poll_votes",
                columns: new[] { "poll_id", "member_id" },
                unique: true);
        }
    }
}
