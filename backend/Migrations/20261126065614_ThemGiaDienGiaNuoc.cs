using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class ThemGiaDienGiaNuoc : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "GiaDien",
                table: "PhongTro",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "GiaNuoc",
                table: "PhongTro",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GiaDien",
                table: "PhongTro");

            migrationBuilder.DropColumn(
                name: "GiaNuoc",
                table: "PhongTro");
        }
    }
}
