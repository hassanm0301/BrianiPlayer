using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Downloads : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "torrent_jobs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UpstreamId = table.Column<string>(type: "TEXT", nullable: true),
                    InfoHashV1 = table.Column<string>(type: "TEXT", nullable: true),
                    InfoHashV2 = table.Column<string>(type: "TEXT", nullable: true),
                    LibraryId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ManagedPath = table.Column<string>(type: "TEXT", nullable: false),
                    MetadataRelativePath = table.Column<string>(type: "TEXT", nullable: true),
                    MetadataFileIdentity = table.Column<string>(type: "TEXT", nullable: true),
                    EncryptedMagnet = table.Column<string>(type: "TEXT", nullable: true),
                    OwnershipTag = table.Column<string>(type: "TEXT", nullable: false),
                    VolumeIdentity = table.Column<string>(type: "TEXT", nullable: false),
                    ReservedBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    ManagedRootIdentity = table.Column<string>(type: "TEXT", nullable: true),
                    RetiredAt = table.Column<long>(type: "INTEGER", nullable: true),
                    PayloadRemoved = table.Column<bool>(type: "INTEGER", nullable: false),
                    Generation = table.Column<long>(type: "INTEGER", nullable: false),
                    MetadataStatus = table.Column<string>(type: "TEXT", nullable: false),
                    EngineState = table.Column<string>(type: "TEXT", nullable: false),
                    DesiredState = table.Column<string>(type: "TEXT", nullable: false),
                    ImportState = table.Column<string>(type: "TEXT", nullable: false),
                    Sequential = table.Column<bool>(type: "INTEGER", nullable: false),
                    MetadataAssist = table.Column<bool>(type: "INTEGER", nullable: false),
                    SelectedComplete = table.Column<bool>(type: "INTEGER", nullable: false),
                    Imported = table.Column<bool>(type: "INTEGER", nullable: false),
                    RemovalDeleteData = table.Column<bool>(type: "INTEGER", nullable: false),
                    PieceLength = table.Column<long>(type: "INTEGER", nullable: false),
                    PieceCount = table.Column<int>(type: "INTEGER", nullable: false),
                    TotalBytes = table.Column<long>(type: "INTEGER", nullable: true),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    ErrorCode = table.Column<string>(type: "TEXT", nullable: true),
                    DownloadedBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    UploadedBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    DownloadBps = table.Column<long>(type: "INTEGER", nullable: false),
                    UploadBps = table.Column<long>(type: "INTEGER", nullable: false),
                    SeedersConnected = table.Column<long>(type: "INTEGER", nullable: true),
                    PeersConnected = table.Column<long>(type: "INTEGER", nullable: true),
                    EtaSeconds = table.Column<long>(type: "INTEGER", nullable: true),
                    SettingsJson = table.Column<string>(type: "TEXT", nullable: false),
                    TagsJson = table.Column<string>(type: "TEXT", nullable: false),
                    SettingsVersion = table.Column<long>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    LastContactAt = table.Column<long>(type: "INTEGER", nullable: true),
                    MetadataDeadline = table.Column<long>(type: "INTEGER", nullable: true),
                    LastReannounceAt = table.Column<long>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_torrent_jobs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_torrent_jobs_libraries_LibraryId",
                        column: x => x.LibraryId,
                        principalTable: "libraries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "download_files",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    TorrentJobId = table.Column<Guid>(type: "TEXT", nullable: false),
                    UpstreamFileIndex = table.Column<int>(type: "INTEGER", nullable: false),
                    MetadataFileIndex = table.Column<int>(type: "INTEGER", nullable: false),
                    RelativePath = table.Column<string>(type: "TEXT", nullable: false),
                    DisplayName = table.Column<string>(type: "TEXT", nullable: false),
                    SizeBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    TorrentOffset = table.Column<long>(type: "INTEGER", nullable: false),
                    PieceFirst = table.Column<int>(type: "INTEGER", nullable: false),
                    PieceLast = table.Column<int>(type: "INTEGER", nullable: false),
                    Padding = table.Column<bool>(type: "INTEGER", nullable: false),
                    Wanted = table.Column<bool>(type: "INTEGER", nullable: false),
                    FilePriority = table.Column<int>(type: "INTEGER", nullable: false),
                    Kind = table.Column<string>(type: "TEXT", nullable: false),
                    Completed = table.Column<bool>(type: "INTEGER", nullable: false),
                    DownloadedBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    ContiguousBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    ImportedItemId = table.Column<Guid>(type: "TEXT", nullable: true),
                    FileIdentity = table.Column<string>(type: "TEXT", nullable: true),
                    MtimeNs = table.Column<long>(type: "INTEGER", nullable: true),
                    PlaybackState = table.Column<string>(type: "TEXT", nullable: false),
                    Version = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_download_files", x => x.Id);
                    table.ForeignKey(
                        name: "FK_download_files_torrent_jobs_TorrentJobId",
                        column: x => x.TorrentJobId,
                        principalTable: "torrent_jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "download_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    OwnerId = table.Column<Guid>(type: "TEXT", nullable: false),
                    AuthSessionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    LibraryId = table.Column<Guid>(type: "TEXT", nullable: false),
                    TorrentJobId = table.Column<Guid>(type: "TEXT", nullable: true),
                    SourceKind = table.Column<string>(type: "TEXT", nullable: false),
                    EncryptedSourceReference = table.Column<string>(type: "TEXT", nullable: false),
                    SourceDigest = table.Column<string>(type: "TEXT", nullable: false),
                    SourceState = table.Column<string>(type: "TEXT", nullable: false),
                    State = table.Column<string>(type: "TEXT", nullable: false),
                    ErrorCode = table.Column<string>(type: "TEXT", nullable: true),
                    SelectedBytes = table.Column<long>(type: "INTEGER", nullable: true),
                    ReservedBytes = table.Column<long>(type: "INTEGER", nullable: false),
                    VolumeIdentity = table.Column<string>(type: "TEXT", nullable: false),
                    IdempotencyKey = table.Column<string>(type: "TEXT", nullable: true),
                    RequestHash = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    RemovedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    Version = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_download_requests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_download_requests_libraries_LibraryId",
                        column: x => x.LibraryId,
                        principalTable: "libraries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_download_requests_torrent_jobs_TorrentJobId",
                        column: x => x.TorrentJobId,
                        principalTable: "torrent_jobs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_download_requests_users_OwnerId",
                        column: x => x.OwnerId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "download_request_files",
                columns: table => new
                {
                    DownloadRequestId = table.Column<Guid>(type: "TEXT", nullable: false),
                    DownloadFileId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Selected = table.Column<bool>(type: "INTEGER", nullable: false),
                    Priority = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_download_request_files", x => new { x.DownloadRequestId, x.DownloadFileId });
                    table.ForeignKey(
                        name: "FK_download_request_files_download_files_DownloadFileId",
                        column: x => x.DownloadFileId,
                        principalTable: "download_files",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_download_request_files_download_requests_DownloadRequestId",
                        column: x => x.DownloadRequestId,
                        principalTable: "download_requests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_download_files_TorrentJobId_UpstreamFileIndex",
                table: "download_files",
                columns: new[] { "TorrentJobId", "UpstreamFileIndex" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_download_request_files_DownloadFileId",
                table: "download_request_files",
                column: "DownloadFileId");

            migrationBuilder.CreateIndex(
                name: "IX_download_requests_LibraryId",
                table: "download_requests",
                column: "LibraryId");

            migrationBuilder.CreateIndex(
                name: "IX_download_requests_OwnerId_IdempotencyKey",
                table: "download_requests",
                columns: new[] { "OwnerId", "IdempotencyKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_download_requests_OwnerId_LibraryId_State",
                table: "download_requests",
                columns: new[] { "OwnerId", "LibraryId", "State" });

            migrationBuilder.CreateIndex(
                name: "IX_download_requests_TorrentJobId",
                table: "download_requests",
                column: "TorrentJobId");

            migrationBuilder.CreateIndex(
                name: "IX_torrent_jobs_InfoHashV1",
                table: "torrent_jobs",
                column: "InfoHashV1",
                unique: true,
                filter: "\"RetiredAt\" IS NULL AND \"InfoHashV1\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_torrent_jobs_InfoHashV2",
                table: "torrent_jobs",
                column: "InfoHashV2",
                unique: true,
                filter: "\"RetiredAt\" IS NULL AND \"InfoHashV2\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_torrent_jobs_LibraryId",
                table: "torrent_jobs",
                column: "LibraryId");

            migrationBuilder.CreateIndex(
                name: "IX_torrent_jobs_UpstreamId",
                table: "torrent_jobs",
                column: "UpstreamId",
                unique: true,
                filter: "\"RetiredAt\" IS NULL AND \"UpstreamId\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "download_request_files");

            migrationBuilder.DropTable(
                name: "download_files");

            migrationBuilder.DropTable(
                name: "download_requests");

            migrationBuilder.DropTable(
                name: "torrent_jobs");
        }
    }
}
