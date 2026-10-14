# M00 lifecycle and preallocation evidence

Date: 2026-10-12. This is a partial, local Linux/amd64 observation against the dedicated `briani-m00-harness` qBittorrent container. It does not change the overall M00 gate status.

## Environment and ownership

The test downloader was label-checked as Compose project `briani-m00-harness`, service `qbittorrent`; the paired seeder is the same isolated test project. The engine runtime report identifies qBittorrent `v5.2.4`, Web API `2.15.1`, and linked libtorrent `2.0.15.0`. The lifecycle test used the existing generated `Tail metadata-v2.torrent` fixture and its already-generated source bytes. No fixture generation or active source replacement occurred. The downloader's `preallocate_all` preference was read as `false` after the failed runs, confirming the helper's `finally` restoration path.

## Observed checks

Command: `python -m py_compile prototypes/playback/lifecycle_checks.py` — exit 0.

The first `python prototypes/playback/lifecycle_checks.py` run exited 1 because the helper initially mishandled a chunked HTTP 503 problem response. Before that failure, it observed that with `preallocate_all=true`, the selected file was incomplete, `st_blocks * 512 >= logical file length`, and a request for a qBittorrent-reported missing piece produced no response during the bounded wait. This is partial T06 evidence that allocation alone did not make unavailable bytes readable.

The helper was updated to parse chunked responses. Its focused parser test passed:

```text
python -m unittest discover -s prototypes/playback -p 'test_lifecycle_checks.py' -v
Ran 1 test — OK
```

The parser unit test passed before the engine reruns. Subsequent engine runs verified the explicit pre-header fence as a JSON HTTP 503, then observed selection-change and recheck fencing. A scoped restart of only `briani-m00-harness-qbittorrent-1` also caused the waiting old-generation request to return HTTP 503 with a JSON 503 status. The run then failed while reconnecting immediately after restart because qBittorrent rotates its session password and may not have its API ready when Docker's restart command returns. The helper gained bounded in-memory credential recovery from the container's temporary-password log. A subsequent run passed the selection/recheck steps but timed out waiting for the restart reader to register. The harness setup script was used to refresh its mode-600 credential file, and a direct API check verified `preallocate_all=false` and the lifecycle-owned torrent stopped at 0% before a retry. No final lifecycle JSON artifact was written; these remain partial observations rather than an overall T09 pass. No user data or non-test container was targeted.

### Sanitized restart-waiter diagnostic

Last reproduction command: `python -m py_compile prototypes/playback/lifecycle_checks.py && python prototypes/playback/lifecycle_checks.py` — exit 1. The failure was at the bounded wait on `GET /proof/state` for `activeReaders == 1`; no HTTP response from the stream socket was collected before that wait failed. At that run's stop point, the test job state was `stoppedDL`, progress `0`, file offset `0`, file length `15,787,543`, piece length `262,144`, and first missing piece `0`; therefore the requested range was `bytes=0-0`. This is a harness observation timeout, not evidence that the request returned a particular status.

`gateway.log` was empty because the proof host clears logging, and no `lifecycle-result.json` exists. In the gateway implementation, `ProofReaders.TryEnter()` increments the counter only after ticket/name authorization, range parsing, and the nonempty-range check. `finally` decrements it after the request ends; the counter includes the initial availability wait, which is bounded at 60 seconds. Thus a counter value that is never sampled as `1` cannot distinguish an early 404/400/503 from a request that entered and exited between 200 ms polls. An earlier run using this path reached the post-restart check and observed the waiting request return HTTP 503 JSON before failing on immediate API reconnect; the latest run did not capture a stream response and cannot confirm that path again.

## Remaining proof

Resolve the restart waiter registration discrepancy, then rerun `python prototypes/playback/lifecycle_checks.py` to produce the complete lifecycle JSON artifact. Preserve the helper's container-label and save-path ownership checks. Do not interpret these partial observations as completion of T06 or T09. The existing full-corpus playback evidence remains separately documented in `docs/evidence/M00/report.md` and `/tmp/briani-full-engine.log`.

## Parent integration correction and successful rerun

The fresh restart host was created while the prior recheck could still be active. Its availability poll could fail closed before the test registered a waiting reader. The parent moved stop-and-settled-state observation before constructing that host. `python prototypes/playback/lifecycle_checks.py` then exited0. `lifecycle-parent.log` and `lifecycle-result.json` contain the complete result: preallocated15790080 bytes against15787543 logical bytes, progress0, unavailable byte withheld, explicit selection/recheck fences503, actual downloader restart waiter503, bounded credential reconnect, preference restored. This establishes local lifecycle byte safety; native hardware/performance gates remain open. Earlier failed attempts remain documented above.
