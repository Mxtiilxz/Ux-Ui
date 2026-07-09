using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kairos.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddQuickMatchSkills : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "QuickMatchVisible",
                table: "users",
                type: "tinyint(1)",
                nullable: false,
                defaultValue: false);

            // NOTE: "Status" (users) and "ImageUrl" (job_postings) are NOT added here
            // even though the scaffolder initially generated AddColumn for both — those
            // columns already exist in every real database via the earlier AddUserStatus
            // and AddJobPostingImageUrl migrations. The model snapshot was out of sync
            // with that migration history (likely hand-authored without regenerating the
            // snapshot), which made the scaffolder think they were new. Removed manually
            // to avoid a "duplicate column" failure on every already-migrated database;
            // the snapshot itself (already regenerated) now correctly reflects them.

            migrationBuilder.CreateTable(
                name: "skills",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("MySql:ValueGenerationStrategy", MySqlValueGenerationStrategy.IdentityColumn),
                    Name = table.Column<string>(type: "varchar(100)", maxLength: 100, nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4"),
                    Category = table.Column<string>(type: "longtext", nullable: false)
                        .Annotation("MySql:CharSet", "utf8mb4")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_skills", x => x.Id);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateTable(
                name: "user_skills",
                columns: table => new
                {
                    UserId = table.Column<int>(type: "int", nullable: false),
                    SkillId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_skills", x => new { x.UserId, x.SkillId });
                    table.ForeignKey(
                        name: "FK_user_skills_skills_SkillId",
                        column: x => x.SkillId,
                        principalTable: "skills",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_user_skills_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                })
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.CreateIndex(
                name: "IX_skills_Name",
                table: "skills",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_user_skills_SkillId",
                table: "user_skills",
                column: "SkillId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "user_skills");

            migrationBuilder.DropTable(
                name: "skills");

            migrationBuilder.DropColumn(
                name: "QuickMatchVisible",
                table: "users");
        }
    }
}
