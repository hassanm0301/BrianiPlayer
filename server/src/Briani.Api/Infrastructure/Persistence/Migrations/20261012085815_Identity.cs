using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Identity : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "audit_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    ActorId = table.Column<Guid>(type: "TEXT", nullable: true),
                    Action = table.Column<string>(type: "TEXT", nullable: false),
                    TargetType = table.Column<string>(type: "TEXT", nullable: false),
                    TargetId = table.Column<string>(type: "TEXT", nullable: false),
                    Result = table.Column<string>(type: "TEXT", nullable: false),
                    SafeDetailsJson = table.Column<string>(type: "TEXT", nullable: false),
                    TraceId = table.Column<string>(type: "TEXT", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_audit_events", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "device_pairings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    DeviceSecretHash = table.Column<string>(type: "TEXT", nullable: false),
                    HumanCodeHash = table.Column<string>(type: "TEXT", nullable: false),
                    DeviceName = table.Column<string>(type: "TEXT", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false),
                    ApprovedBy = table.Column<Guid>(type: "TEXT", nullable: true),
                    ApprovedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    ConsumedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    LastPolledAt = table.Column<long>(type: "INTEGER", nullable: true),
                    PollCount = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_device_pairings", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "libraries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    Description = table.Column<string>(type: "TEXT", nullable: false),
                    RootPath = table.Column<string>(type: "TEXT", nullable: false),
                    RootIdentity = table.Column<string>(type: "TEXT", nullable: false),
                    Enabled = table.Column<bool>(type: "INTEGER", nullable: false),
                    Online = table.Column<bool>(type: "INTEGER", nullable: false),
                    ReadOnly = table.Column<bool>(type: "INTEGER", nullable: false),
                    Managed = table.Column<bool>(type: "INTEGER", nullable: false),
                    ScanIntervalSeconds = table.Column<int>(type: "INTEGER", nullable: true),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    Version = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_libraries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "settings",
                columns: table => new
                {
                    Key = table.Column<string>(type: "TEXT", nullable: false),
                    ValueJson = table.Column<string>(type: "TEXT", nullable: false),
                    Version = table.Column<long>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_settings", x => x.Key);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Username = table.Column<string>(type: "TEXT", nullable: false),
                    NormalizedUsername = table.Column<string>(type: "TEXT", nullable: false),
                    DisplayName = table.Column<string>(type: "TEXT", nullable: false),
                    PasswordHash = table.Column<string>(type: "TEXT", nullable: false),
                    Role = table.Column<string>(type: "TEXT", nullable: false),
                    Enabled = table.Column<bool>(type: "INTEGER", nullable: false),
                    MustChangePassword = table.Column<bool>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    UpdatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    Version = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "auth_sessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    DeviceId = table.Column<string>(type: "TEXT", nullable: false),
                    DeviceName = table.Column<string>(type: "TEXT", nullable: false),
                    Platform = table.Column<string>(type: "TEXT", nullable: false),
                    RefreshHash = table.Column<string>(type: "TEXT", nullable: false),
                    RefreshExpiresAt = table.Column<long>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<long>(type: "INTEGER", nullable: false),
                    LastSeenAt = table.Column<long>(type: "INTEGER", nullable: false),
                    RevokedAt = table.Column<long>(type: "INTEGER", nullable: true),
                    RefreshGeneration = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_auth_sessions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_auth_sessions_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "library_grants",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    LibraryId = table.Column<Guid>(type: "TEXT", nullable: false),
                    CanRead = table.Column<bool>(type: "INTEGER", nullable: false),
                    CanDownload = table.Column<bool>(type: "INTEGER", nullable: false),
                    CanManage = table.Column<bool>(type: "INTEGER", nullable: false),
                    QuotaBytes = table.Column<long>(type: "INTEGER", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_library_grants", x => new { x.UserId, x.LibraryId });
                    table.ForeignKey(
                        name: "FK_library_grants_libraries_LibraryId",
                        column: x => x.LibraryId,
                        principalTable: "libraries",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_library_grants_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "access_tokens",
                columns: table => new
                {
                    TokenHash = table.Column<string>(type: "TEXT", nullable: false),
                    SessionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_access_tokens", x => x.TokenHash);
                    table.ForeignKey(
                        name: "FK_access_tokens_auth_sessions_SessionId",
                        column: x => x.SessionId,
                        principalTable: "auth_sessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "refresh_replays",
                columns: table => new
                {
                    ConsumedHash = table.Column<string>(type: "TEXT", nullable: false),
                    SessionId = table.Column<Guid>(type: "TEXT", nullable: false),
                    ExpiresAt = table.Column<long>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_refresh_replays", x => x.ConsumedHash);
                    table.ForeignKey(
                        name: "FK_refresh_replays_auth_sessions_SessionId",
                        column: x => x.SessionId,
                        principalTable: "auth_sessions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_access_tokens_ExpiresAt",
                table: "access_tokens",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_access_tokens_SessionId",
                table: "access_tokens",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_audit_events_CreatedAt",
                table: "audit_events",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_auth_sessions_RefreshExpiresAt",
                table: "auth_sessions",
                column: "RefreshExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_auth_sessions_RefreshHash",
                table: "auth_sessions",
                column: "RefreshHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_auth_sessions_UserId",
                table: "auth_sessions",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_device_pairings_DeviceSecretHash",
                table: "device_pairings",
                column: "DeviceSecretHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_device_pairings_ExpiresAt",
                table: "device_pairings",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_device_pairings_HumanCodeHash",
                table: "device_pairings",
                column: "HumanCodeHash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_libraries_RootPath",
                table: "libraries",
                column: "RootPath",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_library_grants_LibraryId",
                table: "library_grants",
                column: "LibraryId");

            migrationBuilder.CreateIndex(
                name: "IX_refresh_replays_SessionId",
                table: "refresh_replays",
                column: "SessionId");

            migrationBuilder.CreateIndex(
                name: "IX_users_NormalizedUsername",
                table: "users",
                column: "NormalizedUsername",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "access_tokens");

            migrationBuilder.DropTable(
                name: "audit_events");

            migrationBuilder.DropTable(
                name: "device_pairings");

            migrationBuilder.DropTable(
                name: "library_grants");

            migrationBuilder.DropTable(
                name: "refresh_replays");

            migrationBuilder.DropTable(
                name: "settings");

            migrationBuilder.DropTable(
                name: "libraries");

            migrationBuilder.DropTable(
                name: "auth_sessions");

            migrationBuilder.DropTable(
                name: "users");
        }
    }
}
