using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace Briani.Api.Infrastructure.Persistence.Migrations;

[DbContext(typeof(BrianiDb))]
[Migration("202610120001_Initial")]
public sealed class Initial : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder) => migrationBuilder.CreateTable(
        name: "schema_state", columns: table => new
        {
            Id = table.Column<string>(type: "TEXT", nullable: false),
            PlanVersion = table.Column<string>(type: "TEXT", nullable: false),
            CompatibilityLockHash = table.Column<string>(type: "TEXT", nullable: false)
        }, constraints: table => table.PrimaryKey("PK_schema_state", x => x.Id));
    protected override void Down(MigrationBuilder migrationBuilder) => migrationBuilder.DropTable("schema_state");
}
