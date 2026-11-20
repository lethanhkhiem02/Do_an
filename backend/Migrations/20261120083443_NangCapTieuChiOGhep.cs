using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class NangCapTieuChiOGhep : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GioiTinhUuTien",
                table: "HoSoOGheps",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "KhongHutThuoc",
                table: "HoSoOGheps",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "UaSachSe",
                table: "HoSoOGheps",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GioiTinhUuTien",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "KhongHutThuoc",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "UaSachSe",
                table: "HoSoOGheps");
        }
    }
}
