using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class DownloadOwnership : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "EncryptedMetainfo",
                table: "torrent_jobs",
                type: "TEXT",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "download_ownerships",
                columns: table => new
                {
                    OwnerId = table.Column<Guid>(type: "TEXT", nullable: false),
                    DownloadFileId = table.Column<Guid>(type: "TEXT", nullable: false),
                    LibraryId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Bytes = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_download_ownerships", x => new { x.OwnerId, x.DownloadFileId });
                    table.ForeignKey(
                        name: "FK_download_ownerships_download_files_DownloadFileId",
                        column: x => x.DownloadFileId,
                        principalTable: "download_files",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_download_ownerships_libraries_LibraryId",
                        column: x => x.LibraryId,
                        principalTable: "libraries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_download_ownerships_users_OwnerId",
                        column: x => x.OwnerId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_download_ownerships_DownloadFileId",
                table: "download_ownerships",
                column: "DownloadFileId");

            migrationBuilder.CreateIndex(
                name: "IX_download_ownerships_LibraryId",
                table: "download_ownerships",
                column: "LibraryId");

            migrationBuilder.CreateIndex(
                name: "IX_download_ownerships_OwnerId_LibraryId",
                table: "download_ownerships",
                columns: new[] { "OwnerId", "LibraryId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "download_ownerships");

            migrationBuilder.DropColumn(
                name: "EncryptedMetainfo",
                table: "torrent_jobs");
        }
    }
}
