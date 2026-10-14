# Playback creation retries

Supply a unique Idempotency-Key for each intentional playback session. A retry of the same body by the same authenticated session returns the existing session ID and its current state. A changed body or another authenticated session using that key receives 409.

The initial response contains the raw playback URL. Store that capability on the requesting client. A replay returns `streamUrl: null`: the server stores only the ticket hash and cannot recover its raw value. If the initial URL was lost, revoke the returned session and create a new one with a fresh key. Revoked, expired, or changed targets are never reported as ready.
