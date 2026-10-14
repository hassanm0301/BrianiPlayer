using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class PairingApprovalSession : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ApprovedSessionId",
                table: "device_pairings",
                type: "TEXT",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ApprovedSessionId",
                table: "device_pairings");
        }
    }
}
