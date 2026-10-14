using Briani.Api.Infrastructure.Security;
using Briani.Api.Modules.Discovery.Sources;
using Briani.Api.Modules.Downloads;
using Briani.Api.Modules.Playback;

namespace Briani.DownloadTests;

public sealed class ParserPropertyTests
{
    [Fact]
    public void Verified_available_bytes_match_an_independent_byte_oracle()
    {
        var random=new Random(63781);
        for(var trial=0;trial<2000;trial++) {
            var pieceLength=random.Next(1,65);var offset=random.Next(0,256);var length=random.Next(0,513);
            var pieces=Enumerable.Range(0,random.Next(0,800/pieceLength+1)).Select(_=>(byte)random.Next(0,3)).ToArray();
            var file=new DownloadFile {TorrentOffset=offset,SizeBytes=length,PieceFirst=length==0?0:offset/pieceLength,PieceLast=length==0?-1:(offset+length-1)/pieceLength};
            long available=0,prefix=0;var missing=false;
            for(var b=offset;b<offset+length;b++) {
                var piece=b/pieceLength;var valid=piece<pieces.Length && pieces[piece]==2;
                if(valid)available++;if(!valid)missing=true;if(!missing)prefix++;
            }
            Assert.Equal(available,DownloadLayout.Available(file,pieceLength,pieces));
            Assert.Equal(prefix,DownloadLayout.Available(file,pieceLength,pieces,true));
        }
    }

    [Fact]
    public void Range_parser_matches_independent_intersections_including_large_offsets()
    {
        var random=new Random(87419);
        Assert.Throws<ArgumentOutOfRangeException>(()=>ByteRange.Parse(null,-1));
        foreach(var header in new[]{"Bytes=0-1","bytes=","bytes=--","bytes=-x","bytes=+1-2","bytes=0-+2","bytes=0-1-2","bytes="+new string('1',1025)})
            Assert.Throws<RangeException>(()=>ByteRange.Parse(header,10));
        Assert.False(ByteRange.Parse("bytes=0-1,4-5",10).Partial);
        Assert.Equal(0,ByteRange.Parse(null,0).Length);
        Assert.Throws<RangeException>(()=>ByteRange.Parse("bytes=0-",0));
        for(var trial=0;trial<2000;trial++) {
            var size=random.NextInt64(1,long.MaxValue);var start=random.NextInt64(size);var end=random.NextInt64(start,long.MaxValue);
            var result=ByteRange.Parse($"bytes={start}-{end}",size);
            Assert.Equal(start,result.Start);Assert.Equal(Math.Min(end,size-1),result.End);Assert.True(result.Partial);
            Assert.Equal(size-start,ByteRange.Parse($"bytes={start}-",size).Length);
            var suffix=random.NextInt64(1,long.MaxValue);
            Assert.Equal(Math.Min(size,suffix),ByteRange.Parse($"bytes=-{suffix}",size).Length);
        }
        Assert.Throws<RangeException>(()=>ByteRange.Parse("bytes=-0",10));
        Assert.Throws<RangeException>(()=>ByteRange.Parse("bytes=10-",10));
        Assert.Throws<RangeException>(()=>ByteRange.Parse("bytes=5-4",10));
    }

    [Fact]
    public void Bounded_mutated_metainfo_never_escapes_its_validated_descriptor_or_rejection()
    {
        var random=new Random(96317);var seed=LifecycleFixture.TorrentBytes;
        for(var trial=0;trial<2000;trial++) {
            var bytes=seed.ToArray();
            for(var mutation=0;mutation<1+trial%4;mutation++)bytes[random.Next(bytes.Length)]=(byte)random.Next(256);
            if(trial%5==0)Array.Resize(ref bytes,random.Next(bytes.Length));
            try {
                var parsed=Metainfo.Parse(bytes);
                Assert.InRange(parsed.PieceLength,1,67108864);Assert.InRange(parsed.Files.Length,1,10000);
                Assert.Equal(parsed.Files.Length,parsed.Files.Select(x=>x.Path).Distinct(StringComparer.Ordinal).Count());
                foreach(var file in parsed.Files) {Assert.True(file.Bytes>=0);Assert.DoesNotContain("..",file.Path.Split('/'));Assert.False(Path.IsPathRooted(file.Path));}
                Assert.InRange(DownloadLayout.PieceCount(parsed),0,4000000);
            } catch(ApiException failure) {Assert.Equal(400,failure.Status);}
        }
    }
}
