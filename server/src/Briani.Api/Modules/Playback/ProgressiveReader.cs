using System.Collections;
using Briani.Api.Infrastructure.Storage;
namespace Briani.Api.Modules.Playback;

public sealed class AvailabilitySnapshot(string generation,DateTimeOffset observedAt,bool healthy,byte[] pieces,long engineGeneration=0)
{
    private readonly BitArray readable=new(pieces.Select(x=>x==2).ToArray());
    public string Generation {get;}=generation;
    public DateTimeOffset ObservedAt {get;}=observedAt;
    public bool Healthy {get;}=healthy;
    public long EngineGeneration {get;}=engineGeneration;
    public int PieceCount=>readable.Length;
    public bool Contains(int piece)=>piece>=0 && piece<readable.Length && readable[piece];
    public byte[] CopyStates(){var result=new byte[readable.Length];for(int i=0;i<result.Length;i++)if(readable[i])result[i]=2;return result;}
}
public interface IAvailabilitySource
{
    AvailabilitySnapshot? Current {get;}
    Task WaitForChangeAsync(AvailabilitySnapshot? previous,CancellationToken ct);
}
public sealed class SharedAvailability:IAvailabilitySource
{
    private readonly object sync=new();private AvailabilitySnapshot? current;
    private TaskCompletionSource changed=NewSignal();
    private static TaskCompletionSource NewSignal()=>new(TaskCreationOptions.RunContinuationsAsynchronously);
    public AvailabilitySnapshot? Current {get{lock(sync)return current;}}
    public void Publish(AvailabilitySnapshot value)
    {TaskCompletionSource signal;lock(sync){current=value;signal=changed;changed=NewSignal();}signal.TrySetResult();}
    public AvailabilitySnapshot ReplaceIfCurrent(AvailabilitySnapshot expected,AvailabilitySnapshot value)
    {TaskCompletionSource? signal=null;AvailabilitySnapshot result;lock(sync){if(ReferenceEquals(current,expected)){current=value;signal=changed;changed=NewSignal();}result=current!;}signal?.TrySetResult();return result;}
    public Task WaitForChangeAsync(AvailabilitySnapshot? previous,CancellationToken ct)
    {lock(sync)return ReferenceEquals(previous,current)?changed.Task.WaitAsync(ct):Task.CompletedTask;}
}
public sealed class GenerationException():IOException("generation_changed");
public sealed class DataWaitException():IOException("waiting_for_data");
public sealed record ProgressiveLayout(string Generation,long PieceLength,int PieceCount,long FileOffset,long FileLength,string FileIdentity)
{
    public (int Piece,int Count) Slice(long offset,int count)
    {
        if(PieceLength<=0 || PieceLength>67108864 || PieceCount<0 || FileOffset<0 || FileLength<0 || offset<0 || offset>=FileLength || count<=0)throw new IOException("layout_unverified");
        var address=checked(FileOffset+offset);var piece=checked((int)(address/PieceLength));
        if(piece>=PieceCount)throw new IOException("layout_unverified");
        return(piece,(int)Math.Min(Math.Min(count,FileLength-offset),PieceLength-address%PieceLength));
    }
}
public sealed class ProgressiveReader(ProgressiveLayout layout,IAvailabilitySource availability,TimeProvider clock)
{
    public async ValueTask<int> ReadAsync(FileStream descriptor,long offset,Memory<byte> buffer,TimeSpan timeout,CancellationToken ct)
    {
        var(piece,count)=layout.Slice(offset,buffer.Length);
        using var timer=new CancellationTokenSource(timeout,clock);using var linked=CancellationTokenSource.CreateLinkedTokenSource(ct,timer.Token);
        while(true)
        {
            ct.ThrowIfCancellationRequested();var before=availability.Current;
            if(before is not null && before.Generation!=layout.Generation)throw new GenerationException();
            if(Valid(before,piece))
            {
                var stat=ContainedDirectory.Inspect(descriptor);
                if(stat.Key!=layout.FileIdentity || stat.Length>layout.FileLength)throw new GenerationException();
                if(stat.Length<checked(offset+count))throw new IOException("short_disk_read");
                int got=0;while(got<count){var n=await RandomAccess.ReadAsync(descriptor.SafeFileHandle,buffer.Slice(got,count-got),checked(offset+got),ct);if(n==0)throw new IOException("short_disk_read");got+=n;}
                var after=availability.Current;
                if(after is null || after.Generation!=layout.Generation)throw new GenerationException();
                if(!Valid(after,piece))throw new IOException("availability_invalidated");
                return got;
            }
            try{await availability.WaitForChangeAsync(before,linked.Token);}
            catch(OperationCanceledException)when(!ct.IsCancellationRequested){throw new DataWaitException();}
        }
    }
    private bool Valid(AvailabilitySnapshot? s,int piece)=>s is not null && s.Healthy && s.PieceCount==layout.PieceCount && clock.GetUtcNow()-s.ObservedAt>=TimeSpan.Zero && clock.GetUtcNow()-s.ObservedAt<=TimeSpan.FromSeconds(2) && s.Contains(piece);
}
