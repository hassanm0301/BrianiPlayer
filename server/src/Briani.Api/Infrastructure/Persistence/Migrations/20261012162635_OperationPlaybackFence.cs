using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class OperationPlaybackFence : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "InvalidatesPlayback",
                table: "operations",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
            // Existing queued commands predate the explicit discriminator. Fence
            // their unsafe kinds conservatively during upgrade recovery.
            migrationBuilder.Sql("UPDATE operations SET InvalidatesPlayback = 1 WHERE Kind IN ('download-select','download-recheck','download-retry','download-remove') AND State IN ('pending','running')");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "InvalidatesPlayback",
                table: "operations");
        }
    }
}
