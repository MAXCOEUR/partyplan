using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PartyPlan.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class DiscussionMentionsEtEpingles : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "poll_id",
                table: "messages",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "message_mentions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    message_id = table.Column<Guid>(type: "uuid", nullable: false),
                    member_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_message_mentions", x => x.id);
                    table.ForeignKey(
                        name: "fk_message_mentions_messages_message_id",
                        column: x => x.message_id,
                        principalTable: "messages",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "pin_folders",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    event_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    created_by_member_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_pin_folders", x => x.id);
                    table.ForeignKey(
                        name: "fk_pin_folders_events_event_id",
                        column: x => x.event_id,
                        principalTable: "events",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "pinned_messages",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    event_id = table.Column<Guid>(type: "uuid", nullable: false),
                    message_id = table.Column<Guid>(type: "uuid", nullable: false),
                    folder_id = table.Column<Guid>(type: "uuid", nullable: true),
                    pinned_by_member_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_pinned_messages", x => x.id);
                    table.ForeignKey(
                        name: "fk_pinned_messages_messages_message_id",
                        column: x => x.message_id,
                        principalTable: "messages",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_pinned_messages_pin_folders_folder_id",
                        column: x => x.folder_id,
                        principalTable: "pin_folders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "ix_message_mentions_message_id_member_id",
                table: "message_mentions",
                columns: new[] { "message_id", "member_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_pin_folders_event_id_name",
                table: "pin_folders",
                columns: new[] { "event_id", "name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_pinned_messages_event_id_folder_id",
                table: "pinned_messages",
                columns: new[] { "event_id", "folder_id" });

            migrationBuilder.CreateIndex(
                name: "ix_pinned_messages_folder_id",
                table: "pinned_messages",
                column: "folder_id");

            migrationBuilder.CreateIndex(
                name: "ix_pinned_messages_message_id",
                table: "pinned_messages",
                column: "message_id",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "message_mentions");

            migrationBuilder.DropTable(
                name: "pinned_messages");

            migrationBuilder.DropTable(
                name: "pin_folders");

            migrationBuilder.DropColumn(
                name: "poll_id",
                table: "messages");
        }
    }
}
