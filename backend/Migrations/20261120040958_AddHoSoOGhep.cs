using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Do_an_co_so.Migrations
{
    /// <inheritdoc />
    public partial class AddHoSoOGhep : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "HoSoOGheps",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    GioGiacSinhHoat = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CoNauAn = table.Column<bool>(type: "bit", nullable: false),
                    CoNuoiPet = table.Column<bool>(type: "bit", nullable: false),
                    NganSachToiDa = table.Column<decimal>(type: "decimal(18,2)", nullable: false),
                    KhuVucMongMuon = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    MoTaThem = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    DangTimBan = table.Column<bool>(type: "bit", nullable: false),
                    NgayCapNhat = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HoSoOGheps", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HoSoOGheps_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_HoSoOGheps_UserId",
                table: "HoSoOGheps",
                column: "UserId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "HoSoOGheps");
        }
    }
}
