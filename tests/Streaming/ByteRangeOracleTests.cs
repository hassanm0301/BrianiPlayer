using Briani.Api.Modules.Playback;

namespace Briani.StreamingTests;

public sealed class ByteRangeOracleTests
{
    [Theory]
    [InlineData("bytes=0-0", 10, 0, 0)]
    [InlineData("bytes=3-7", 10, 3, 7)]
    [InlineData("bytes=8-99", 10, 8, 9)]
    [InlineData("bytes=5-", 10, 5, 9)]
    [InlineData("bytes=-1", 10, 9, 9)]
    [InlineData("bytes=-4", 10, 6, 9)]
    [InlineData("bytes=-40", 10, 0, 9)]
    public void Single_and_suffix_ranges_resolve_against_final_length(string header, long size, long start, long end)
    {
        var range = ByteRange.Parse(header, size);
        Assert.True(range.Partial);
        Assert.Equal(start, range.Start);
        Assert.Equal(end, range.End);
        Assert.Equal(end - start + 1, range.Length);
    }

    [Theory]
    [InlineData(null, 0, 0, -1)]
    [InlineData("", 10, 0, 9)]
    public void Full_entity_ranges_preserve_the_known_final_length(string? header, long size, long start, long end)
    {
        var range = ByteRange.Parse(header, size);
        Assert.False(range.Partial);
        Assert.Equal(start, range.Start);
        Assert.Equal(end, range.End);
        Assert.Equal(size, range.Length);
    }

    [Fact]
    public void Multiple_ranges_follow_documented_ignore_and_full_response_fallback()
    {
        var range = ByteRange.Parse("bytes=0-1,5-8", 20);
        Assert.False(range.Partial);
        Assert.Equal(new ByteRange(0, 19, false), range);
    }

    [Theory]
    [InlineData("bytes=-0")]
    [InlineData("bytes=10-")]
    [InlineData("bytes=8-7")]
    public void Unsatisfiable_ranges_are_reported_without_wrapping_offsets(string header)
    {
        var error = Assert.Throws<RangeException>(() => ByteRange.Parse(header, 10));
        Assert.True(error.Unsatisfiable);
    }

    [Theory]
    [InlineData("bytes=9223372036854775808-")]
    [InlineData("bytes=0-9223372036854775808")]
    public void Overflowing_decimal_offsets_are_malformed_not_wrapped(string header)
    {
        var error = Assert.Throws<RangeException>(() => ByteRange.Parse(header, 10));
        Assert.False(error.Unsatisfiable);
    }

    [Theory]
    [InlineData("bytes=abc-def")]
    [InlineData("bytes=1.2-4")]
    [InlineData("bytes= 1-2")]
    [InlineData("bytes=1 -2")]
    [InlineData("bytes=1-2-3")]
    [InlineData("Bytes=0-1")]
    [InlineData("items=0-1")]
    [InlineData("bytes=+1-2")]
    [InlineData("bytes=--1")]
    public void Malformed_range_syntax_is_rejected_as_a_parse_error(string header)
    {
        var error = Assert.Throws<RangeException>(() => ByteRange.Parse(header, 10));
        Assert.False(error.Unsatisfiable);
    }

    [Fact]
    public void Empty_representation_and_start_past_end_are_unsatisfiable()
    {
        Assert.True(Assert.Throws<RangeException>(() => ByteRange.Parse("bytes=0-0", 0)).Unsatisfiable);
        Assert.True(Assert.Throws<RangeException>(() => ByteRange.Parse("bytes=10-", 10)).Unsatisfiable);
    }

    [Fact]
    public void Header_and_entity_length_bounds_are_checked_before_allocating_or_copying()
    {
        Assert.Throws<ArgumentOutOfRangeException>(() => ByteRange.Parse(null, -1));
        Assert.False(Assert.Throws<RangeException>(() => ByteRange.Parse("bytes=" + new string('1', 1019), 10)).Unsatisfiable);
    }

    [Fact]
    public void Deterministic_random_ranges_match_an_independent_byte_interval_oracle()
    {
        var random = new Random(0xC0FFEE);
        for (var i = 0; i < 500; i++)
        {
            var size = random.Next(1, 1_000_000);
            var start = random.NextInt64(0, size);
            var requestedEnd = random.NextInt64(start, size + 1000L);
            var parsed = ByteRange.Parse($"bytes={start}-{requestedEnd}", size);
            var expectedEnd = Math.Min(requestedEnd, size - 1);
            Assert.Equal(start, parsed.Start);
            Assert.Equal(expectedEnd, parsed.End);
            Assert.Equal(expectedEnd - start + 1, parsed.Length);
            Assert.True(parsed.Partial);
        }
    }

    [Fact]
    public void Head_uses_same_metadata_range_resolution_without_payload_wait_or_body_semantics()
    {
        // ByteRange only parses the metadata Range field. The HTTP handler is responsible for HEAD's no-body rule.
        var range = ByteRange.Parse("bytes=5-9", 20);
        Assert.Equal(new ByteRange(5, 9, true), range);
        Assert.Equal(5, range.Length);
    }
}
