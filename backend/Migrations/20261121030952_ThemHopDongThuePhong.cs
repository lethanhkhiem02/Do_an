using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class ThemHopDongThuePhong : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "HopDongs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PhongTroId = table.Column<int>(type: "int", nullable: false),
                    BenAId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    TenBenA = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    NgaySinhBenA = table.Column<DateTime>(type: "datetime2", nullable: true),
                    BenBId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    TenBenB = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    NgaySinhBenB = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DiaChiPhong = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    GiaThue = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    ThoiHanThang = table.Column<int>(type: "int", nullable: false),
                    NgayBatDau = table.Column<DateTime>(type: "datetime2", nullable: false),
                    TrangThai = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    KyBenALuc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    KyBenBLuc = table.Column<DateTime>(type: "datetime2", nullable: true),
                    NgayLap = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HopDongs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HopDongs_AspNetUsers_BenAId",
                        column: x => x.BenAId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HopDongs_AspNetUsers_BenBId",
                        column: x => x.BenBId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HopDongs_PhongTro_PhongTroId",
                        column: x => x.PhongTroId,
                        principalTable: "PhongTro",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HopDongs_BenAId",
                table: "HopDongs",
                column: "BenAId");

            migrationBuilder.CreateIndex(
                name: "IX_HopDongs_BenBId",
                table: "HopDongs",
                column: "BenBId");

            migrationBuilder.CreateIndex(
                name: "IX_HopDongs_PhongTroId",
                table: "HopDongs",
                column: "PhongTroId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HopDongs");
        }
    }
}
