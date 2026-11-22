using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class AddLocAnhVaCanhBaoAI : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ImageHash",
                table: "PhongTro",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CanhBaoBatThuongs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    PhongTroId = table.Column<int>(type: "int", nullable: true),
                    LoaiViPham = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    MoTaChiTiet = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    AnhBangChungUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    DaXuLy = table.Column<bool>(type: "bit", nullable: false),
                    NgayTao = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CanhBaoBatThuongs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CanhBaoBatThuongs_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CanhBaoBatThuongs_PhongTro_PhongTroId",
                        column: x => x.PhongTroId,
                        principalTable: "PhongTro",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CanhBaoBatThuongs_PhongTroId",
                table: "CanhBaoBatThuongs",
                column: "PhongTroId");

            migrationBuilder.CreateIndex(
                name: "IX_CanhBaoBatThuongs_UserId",
                table: "CanhBaoBatThuongs",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CanhBaoBatThuongs");

            migrationBuilder.DropColumn(
                name: "ImageHash",
                table: "PhongTro");
        }
    }
}
