using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Media : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "jobs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Kind = table.Column<string>(type: "TEXT", nullable: false),
                    TargetId = table.Column<Guid>(type: "TEXT", nullable: false),
                    PayloadJson = table.Column<string>(type: "TEXT", nullable: false),
                    DedupKey = table.Column<string>(type: "TEXT", nullable: true),
                    State = table.Column<string>(type: "TEXT", nullable: false),
                    Attempt = table.Column<int>(type: "INTEGER", nullable: false),
                    NextAttemptAt = table.Column<long>(type: "INTEGER", nullable: false),
                    LeaseOwner = table.Column<string>(type: "TEXT", nullable: true),
                    LeaseUntil = table.Column<long>(type: "INTEGER", nullable: true),
                    LastErrorCode = table.Column<string>(type: "TEXT", nullable: true),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    Progress = table.Column<double>(type: "REAL", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_jobs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "media_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    LibraryId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ParentId = table.Column<Guid>(type: "TEXT", nullable: true),
                    ParentRelativePath = table.Column<string>(type: "TEXT", nullable: false),
                    RelativePath = table.Column<string>(type: "TEXT", nullable: false),
                    DisplayName = table.Column<string>(type: "TEXT", nullable: false),
                    SearchKey = table.Column<string>(type: "TEXT", nullable: false),
                    Kind = table.Column<string>(type: "TEXT", nullable: false),
                    Extension = table.Column<string>(type: "TEXT", nullable: false),
                    MimeType = table.Column<string>(type: "TEXT", nullable: false),
                    SizeBytes = table.Column<long>(type: "INTEGER", nullable: true),
                    MtimeNs = table.Column<long>(type: "INTEGER", nullable: false),
                    FileIdentity = table.Column<string>(type: "TEXT", nullable: false),
                    SourceKind = table.Column<string>(type: "TEXT", nullable: false),
                    DownloadFileId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Lifecycle = table.Column<string>(type: "TEXT", nullable: false),
                    MissingSince = table.Column<long>(type: "INTEGER", nullable: true),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    IndexedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    Version = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_media_items", x => x.Id);
                    table.ForeignKey(
                        name: "FK_media_items_libraries_LibraryId",
                        column: x => x.LibraryId,
                        principalTable: "libraries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "operations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Kind = table.Column<string>(type: "TEXT", nullable: false),
                    TargetId = table.Column<Guid>(type: "TEXT", nullable: false),
                    IdempotencyKey = table.Column<string>(type: "TEXT", nullable: true),
                    RequestHash = table.Column<string>(type: "TEXT", nullable: false),
                    State = table.Column<string>(type: "TEXT", nullable: false),
                    ResultJson = table.Column<string>(type: "TEXT", nullable: false),
                    PayloadJson = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_operations", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "media_metadata",
                columns: table => new
                {
                    MediaItemId = table.Column<Guid>(type: "TEXT", nullable: false),
                    DurationMs = table.Column<long>(type: "INTEGER", nullable: true),
                    Width = table.Column<int>(type: "INTEGER", nullable: true),
                    Height = table.Column<int>(type: "INTEGER", nullable: true),
                    Rotation = table.Column<int>(type: "INTEGER", nullable: true),
                    ExifOrientation = table.Column<int>(type: "INTEGER", nullable: true),
                    VideoCodec = table.Column<string>(type: "TEXT", nullable: true),
                    TracksJson = table.Column<string>(type: "TEXT", nullable: false),
                    Container = table.Column<string>(type: "TEXT", nullable: false),
                    ProbeVersion = table.Column<string>(type: "TEXT", nullable: false),
                    ProbeStatus = table.Column<string>(type: "TEXT", nullable: false),
                    ProbeErrorCode = table.Column<string>(type: "TEXT", nullable: true),
                    ContentGeneration = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_media_metadata", x => x.MediaItemId);
                    table.ForeignKey(
                        name: "FK_media_metadata_media_items_MediaItemId",
                        column: x => x.MediaItemId,
                        principalTable: "media_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "playback_progress",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    MediaItemId = table.Column<Guid>(type: "TEXT", nullable: false),
                    PositionMs = table.Column<long>(type: "INTEGER", nullable: false),
                    DurationMs = table.Column<long>(type: "INTEGER", nullable: true),
                    Completed = table.Column<bool>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    ClientEventId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Version = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_playback_progress", x => new { x.UserId, x.MediaItemId });
                    table.ForeignKey(
                        name: "FK_playback_progress_media_items_MediaItemId",
                        column: x => x.MediaItemId,
                        principalTable: "media_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_playback_progress_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "playback_sessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    AuthSessionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    MediaItemId = table.Column<Guid>(type: "TEXT", nullable: true),
                    DownloadFileId = table.Column<Guid>(type: "TEXT", nullable: true),
                    TargetGeneration = table.Column<string>(type: "TEXT", nullable: false),
                    TicketHash = table.Column<string>(type: "TEXT", nullable: false),
                    Mode = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    FirstUseDeadline = table.Column<long>(type: "INTEGER", nullable: false),
                    AbsoluteExpiresAt = table.Column<long>(type: "INTEGER", nullable: false),
                    ActivatedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    LastActivityAt = table.Column<long>(type: "INTEGER", nullable: true),
                    RevokedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    InitialPositionMs = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_playback_sessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_playback_sessions_auth_sessions_AuthSessionId",
                        column: x => x.AuthSessionId,
                        principalTable: "auth_sessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_playback_sessions_media_items_MediaItemId",
                        column: x => x.MediaItemId,
                        principalTable: "media_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_playback_sessions_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "thumbnail_entries",
                columns: table => new
                {
                    MediaItemId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Generation = table.Column<long>(type: "INTEGER", nullable: false),
                    Variant = table.Column<string>(type: "TEXT", nullable: false),
                    CacheRelativePath = table.Column<string>(type: "TEXT", nullable: false),
                    FileIdentity = table.Column<string>(type: "TEXT", nullable: false),
                    Bytes = table.Column<long>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    LastAccessedAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_thumbnail_entries", x => new { x.MediaItemId, x.Generation, x.Variant });
                    table.ForeignKey(
                        name: "FK_thumbnail_entries_media_items_MediaItemId",
                        column: x => x.MediaItemId,
                        principalTable: "media_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_jobs_DedupKey",
                table: "jobs",
                column: "DedupKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_jobs_State_NextAttemptAt",
                table: "jobs",
                columns: new[] { "State", "NextAttemptAt" });

            migrationBuilder.CreateIndex(
                name: "IX_media_items_LibraryId_ParentId_SearchKey",
                table: "media_items",
                columns: new[] { "LibraryId", "ParentId", "SearchKey" });

            migrationBuilder.CreateIndex(
                name: "IX_media_items_LibraryId_RelativePath",
                table: "media_items",
                columns: new[] { "LibraryId", "RelativePath" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_operations_UserId_Kind_IdempotencyKey",
                table: "operations",
                columns: new[] { "UserId", "Kind", "IdempotencyKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_playback_progress_MediaItemId",
                table: "playback_progress",
                column: "MediaItemId");

            migrationBuilder.CreateIndex(
                name: "IX_playback_progress_UserId_UpdatedAt",
                table: "playback_progress",
                columns: new[] { "UserId", "UpdatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_playback_sessions_AbsoluteExpiresAt",
                table: "playback_sessions",
                column: "AbsoluteExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_playback_sessions_AuthSessionId",
                table: "playback_sessions",
                column: "AuthSessionId");

            migrationBuilder.CreateIndex(
                name: "IX_playback_sessions_MediaItemId",
                table: "playback_sessions",
                column: "MediaItemId");

            migrationBuilder.CreateIndex(
                name: "IX_playback_sessions_TicketHash",
                table: "playback_sessions",
                column: "TicketHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_playback_sessions_UserId",
                table: "playback_sessions",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "jobs");

            migrationBuilder.DropTable(
                name: "media_metadata");

            migrationBuilder.DropTable(
                name: "operations");

            migrationBuilder.DropTable(
                name: "playback_progress");

            migrationBuilder.DropTable(
                name: "playback_sessions");

            migrationBuilder.DropTable(
                name: "thumbnail_entries");

            migrationBuilder.DropTable(
                name: "media_items");
        }
    }
}
