using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
namespace Briani.Api.Infrastructure.Persistence;
public sealed class DesignFactory : IDesignTimeDbContextFactory<BrianiDb>
{ public BrianiDb CreateDbContext(string[] args)=>new(new DbContextOptionsBuilder<BrianiDb>().UseSqlite("Data Source=:memory:").Options); }
