using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Discovery : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "discovery_snapshots",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    AuthSessionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    PermissionStamp = table.Column<string>(type: "TEXT", nullable: false),
                    QueryKey = table.Column<string>(type: "TEXT", nullable: false),
                    QueryJson = table.Column<string>(type: "TEXT", nullable: false),
                    State = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false),
                    FetchedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    Truncated = table.Column<bool>(type: "INTEGER", nullable: false),
                    WarningsJson = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_discovery_snapshots", x => x.Id);
                    table.ForeignKey(
                        name: "FK_discovery_snapshots_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "torrent_uploads",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    RelativePath = table.Column<string>(type: "TEXT", nullable: false),
                    FileIdentity = table.Column<string>(type: "TEXT", nullable: false),
                    Sha256 = table.Column<string>(type: "TEXT", nullable: false),
                    Bytes = table.Column<long>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_torrent_uploads", x => x.Id);
                    table.ForeignKey(
                        name: "FK_torrent_uploads_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "discovery_results",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    SnapshotId = table.Column<Guid>(type: "TEXT", nullable: false),
                    SourceId = table.Column<string>(type: "TEXT", nullable: false),
                    SourceName = table.Column<string>(type: "TEXT", nullable: false),
                    SourceGuid = table.Column<string>(type: "TEXT", nullable: false),
                    Title = table.Column<string>(type: "TEXT", nullable: false),
                    Bytes = table.Column<long>(type: "INTEGER", nullable: true),
                    Seeders = table.Column<long>(type: "INTEGER", nullable: true),
                    Leechers = table.Column<long>(type: "INTEGER", nullable: true),
                    PeersTotal = table.Column<long>(type: "INTEGER", nullable: true),
                    PublishedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    ObservedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    InfoHashV1 = table.Column<string>(type: "TEXT", nullable: true),
                    InfoHashV2 = table.Column<string>(type: "TEXT", nullable: true),
                    CategoriesJson = table.Column<string>(type: "TEXT", nullable: false),
                    EncryptedResolutionJson = table.Column<string>(type: "TEXT", nullable: false),
                    CanDownload = table.Column<bool>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_discovery_results", x => x.Id);
                    table.ForeignKey(
                        name: "FK_discovery_results_discovery_snapshots_SnapshotId",
                        column: x => x.SnapshotId,
                        principalTable: "discovery_snapshots",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_discovery_results_SnapshotId",
                table: "discovery_results",
                column: "SnapshotId");

            migrationBuilder.CreateIndex(
                name: "IX_discovery_snapshots_ExpiresAt",
                table: "discovery_snapshots",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_discovery_snapshots_UserId_QueryKey",
                table: "discovery_snapshots",
                columns: new[] { "UserId", "QueryKey" });

            migrationBuilder.CreateIndex(
                name: "IX_torrent_uploads_ExpiresAt",
                table: "torrent_uploads",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_torrent_uploads_UserId",
                table: "torrent_uploads",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "discovery_results");

            migrationBuilder.DropTable(
                name: "torrent_uploads");

            migrationBuilder.DropTable(
                name: "discovery_snapshots");
        }
    }
}
