namespace Briani.Api.Modules.Playback;
public sealed class MediaReaders
{
    private readonly object sync=new();private readonly Dictionary<Guid,Lease> active=new();
    public Lease Acquire(Guid session,Guid media,CancellationToken request)
    {lock(sync){if(active.Count>=16 || active.Values.Count(x=>x.SessionId==session)>=4)throw new Briani.Api.Infrastructure.Security.ApiException(429,"reader_limit");var lease=new Lease(this,session,media,request);active.Add(lease.Id,lease);return lease;}}
    public Guid[] ActiveMediaIds(){lock(sync)return active.Values.Select(x=>x.MediaId).Distinct().ToArray();}
    public bool HasReaders(Guid media){lock(sync)return active.Values.Any(x=>x.MediaId==media);}
    public void CancelSession(Guid session){Lease[] leases;lock(sync)leases=active.Values.Where(x=>x.SessionId==session).ToArray();foreach(var l in leases)l.Cancel();}
    public void Cancel(Guid media){Lease[] leases;lock(sync)leases=active.Values.Where(x=>x.MediaId==media).ToArray();foreach(var l in leases)l.Cancel();}
    public sealed class Lease:IDisposable
    {
        private readonly MediaReaders owner;private readonly CancellationTokenSource cancel;
        public Guid Id {get;}=Guid.NewGuid();public Guid SessionId{get;}public Guid MediaId{get;}public CancellationToken Token=>cancel.Token;
        internal Lease(MediaReaders owner,Guid session,Guid media,CancellationToken request){this.owner=owner;SessionId=session;MediaId=media;cancel=CancellationTokenSource.CreateLinkedTokenSource(request);}
        internal void Cancel(){try{cancel.Cancel();}catch(ObjectDisposedException){}}
        public void Dispose(){lock(owner.sync){owner.active.Remove(Id);cancel.Dispose();}}
    }
}
