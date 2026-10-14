using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Briani.Api.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class TorrentRevision : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<long>(
                name: "Revision",
                table: "torrent_jobs",
                type: "INTEGER",
                nullable: false,
                defaultValue: 1L);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Revision",
                table: "torrent_jobs");
        }
    }
}
