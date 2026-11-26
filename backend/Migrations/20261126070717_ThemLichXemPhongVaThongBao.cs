using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class ThemLichXemPhongVaThongBao : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "LichXemPhongs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PhongTroId = table.Column<int>(type: "int", nullable: false),
                    NguoiDatId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    ChuTroId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    NgayHen = table.Column<DateTime>(type: "datetime2", nullable: false),
                    GhiChu = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: true),
                    TrangThai = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    NgayTao = table.Column<DateTime>(type: "datetime2", nullable: false),
                    NgayPhanHoi = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LichXemPhongs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LichXemPhongs_AspNetUsers_ChuTroId",
                        column: x => x.ChuTroId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LichXemPhongs_AspNetUsers_NguoiDatId",
                        column: x => x.NguoiDatId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LichXemPhongs_PhongTro_PhongTroId",
                        column: x => x.PhongTroId,
                        principalTable: "PhongTro",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ThongBaos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    NguoiNhanId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Loai = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    TacNhanId = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    MaLichXemPhong = table.Column<int>(type: "int", nullable: true),
                    DaDoc = table.Column<bool>(type: "bit", nullable: false),
                    NgayTao = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ThongBaos", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ThongBaos_AspNetUsers_NguoiNhanId",
                        column: x => x.NguoiNhanId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ThongBaos_AspNetUsers_TacNhanId",
                        column: x => x.TacNhanId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_LichXemPhongs_ChuTroId",
                table: "LichXemPhongs",
                column: "ChuTroId");

            migrationBuilder.CreateIndex(
                name: "IX_LichXemPhongs_NguoiDatId",
                table: "LichXemPhongs",
                column: "NguoiDatId");

            migrationBuilder.CreateIndex(
                name: "IX_LichXemPhongs_PhongTroId_NguoiDatId",
                table: "LichXemPhongs",
                columns: new[] { "PhongTroId", "NguoiDatId" });

            migrationBuilder.CreateIndex(
                name: "IX_ThongBaos_NguoiNhanId_DaDoc",
                table: "ThongBaos",
                columns: new[] { "NguoiNhanId", "DaDoc" });

            migrationBuilder.CreateIndex(
                name: "IX_ThongBaos_TacNhanId",
                table: "ThongBaos",
                column: "TacNhanId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LichXemPhongs");

            migrationBuilder.DropTable(
                name: "ThongBaos");
        }
    }
}
