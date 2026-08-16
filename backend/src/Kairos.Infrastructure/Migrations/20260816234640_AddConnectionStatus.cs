using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kairos.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddConnectionStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "RespondedAt",
                table: "follows",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "follows",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValue: "pending");

            migrationBuilder.CreateIndex(
                name: "IX_follows_FollowedId_Status",
                table: "follows",
                columns: new[] { "FollowedId", "Status" });

            // Las relaciones anteriores se crearon cuando seguir era unilateral
            // y no requería el consentimiento de nadie. Se dan por aceptadas: lo
            // contrario dejaría a todo el mundo con una bandeja de solicitudes
            // que nunca pidió, y esas conexiones ya se estaban usando.
            migrationBuilder.Sql(
                """
                UPDATE follows
                SET "Status" = 'accepted', "RespondedAt" = "CreatedAt";
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_follows_FollowedId_Status",
                table: "follows");

            migrationBuilder.DropColumn(
                name: "RespondedAt",
                table: "follows");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "follows");
        }
    }
}
