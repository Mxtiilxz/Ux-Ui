using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Kairos.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPostImageAltText : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ImageAltText",
                table: "posts",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ImageAltText",
                table: "posts");
        }
    }
}
