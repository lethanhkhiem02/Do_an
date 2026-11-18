using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class ThemCacheDichNoiDung : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "DichNoiDungs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    NgonNgu = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false),
                    MaHash = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    VanBanGoc = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    BanDich = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    NgayTao = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DichNoiDungs", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DichNoiDungs_NgonNgu_MaHash",
                table: "DichNoiDungs",
                columns: new[] { "NgonNgu", "MaHash" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DichNoiDungs");
        }
    }
}
