using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kairos.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddUserApprovedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "ApprovedAt",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            // Las cuentas que ya estaban aprobadas antes de existir esta columna
            // se quedarían fuera del historial de altas por no tener fecha. Se
            // toma la de creación, que es la mejor aproximación disponible.
            migrationBuilder.Sql(
                """
                UPDATE users
                SET "ApprovedAt" = "CreatedAt"
                WHERE "Status" = 'approved' AND "ApprovedAt" IS NULL;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ApprovedAt",
                table: "users");
        }
    }
}
