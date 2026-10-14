using Briani.Api.Infrastructure.Storage;
namespace Briani.MediaTests;
public sealed class MountLocationTests
{
    [Theory]
    [InlineData("/", "/config/state", true)]
    [InlineData("/data", "/data/library", true)]
    [InlineData("/data", "/database", false)]
    [InlineData("/same", "/same", true)]
    public void Bind_mapping_detects_physical_ancestors_in_both_directions(string first,string second,bool expected)
    {var a=new MountLocation("0:1",first);var b=new MountLocation("0:1",second);Assert.Equal(expected,a.Overlaps(b));Assert.Equal(expected,b.Overlaps(a));Assert.False(a.Overlaps(new("0:2",second)));}
}
