using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class NangCapNghiepVuOGhep : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "DaCoPhong",
                table: "HoSoOGheps",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "DiaChiPhongHienTai",
                table: "HoSoOGheps",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "GiaChiaMoiNguoi",
                table: "HoSoOGheps",
                type: "decimal(18,2)",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "PhongTroId",
                table: "HoSoOGheps",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ThoiGianDonVao",
                table: "HoSoOGheps",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_HoSoOGheps_PhongTroId",
                table: "HoSoOGheps",
                column: "PhongTroId");

            migrationBuilder.AddForeignKey(
                name: "FK_HoSoOGheps_PhongTro_PhongTroId",
                table: "HoSoOGheps",
                column: "PhongTroId",
                principalTable: "PhongTro",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_HoSoOGheps_PhongTro_PhongTroId",
                table: "HoSoOGheps");

            migrationBuilder.DropIndex(
                name: "IX_HoSoOGheps_PhongTroId",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "DaCoPhong",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "DiaChiPhongHienTai",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "GiaChiaMoiNguoi",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "PhongTroId",
                table: "HoSoOGheps");

            migrationBuilder.DropColumn(
                name: "ThoiGianDonVao",
                table: "HoSoOGheps");
        }
    }
}
