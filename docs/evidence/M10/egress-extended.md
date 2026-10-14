# M10 independent daemon egress paths

2026-10-13. Local Linux amd64, actual locked qBittorrent `v5.2.4`, libtorrent `2.0.15.0`. The original `egress.json` remains preserved (SHA256 `e5ede14d44640eeae6d3c5a00c725ca370758c83523e9ee568cd35e64dc71689`). This extension separates paths that the baseline combined.

## Executed result

Final command, **exit 0**:

```sh
timeout --signal=INT 300s python tools/security/egress_probe.py --output docs/evidence/M10/egress-extended2.json
```

Stdout/stderr: `/tmp/briani-m10-egress-extended2.log`. Structured evidence: `egress-extended2.json`, run `ddedf365b9a84d0e9d1084c6809c10e7`. Docker calls use repository-scoped `.tools/docker-config`. No remote Pi or host firewall operation occurred.

| Actual daemon path | Separate target port | Denied TCP packets | Target hits | Daemon positive observed |
|---|---:|---:|---:|---|
| HTTP tracker | 18100 | 1 | 0 | yes |
| HTTP webseed | 18101 | 1 | 0 | yes |
| Explicit TCP peer | 18102 | 1 | 0 | yes |
| Tracker HTTP redirect | 18103 | 1 | 0 | yes |
| Webseed HTTP redirect | 18104 | 1 | 0 | yes |
| Tracker DNS rebinding | 18105 | 1 | 0 | yes |
| Webseed DNS rebinding | 18106 | 1 | 0 | yes |

Every receiving port additionally had one successful live-target control from the owned origin container. Each daemon path first exercised an actual allowed request/peer attempt. Generated torrents contain one 16 KiB zero-byte payload, unique harmless filenames, no public trackers and private-swarm mode; DHT/PEX/LSD/UPnP were disabled. No copyrighted fixture or indexer credentials were used.

## Method and containment

Four fresh containers and one network have exact random run labels. All cleanup revalidates the run label and removes exact container IDs; network removal also requires emptiness. Final cleanup succeeded. The fixture runs as the host UID/GID, read-only except its fresh owned event directory, without capabilities. Only the guard has NET_ADMIN inside its own network namespace. Actual image IDs/build information are in the JSON artifact.

Each negative port has a **counter-only rule**, which continues into the production policy. The probe does not install its own reject/drop verdict to manufacture a denial. Separate destination ports prevent another path's retries from contributing to its counter/hit result. `not_proven` is returned when a positive control, attempted blocked packet or redirect/DNS phase is absent.

The only temporary allow rules target the exact owned origin IPv4 with TCP 18080, TCP 18105/18106 for DNS first-phase HTTP, and UDP 53 for its authoritative fixture DNS. No private subnet wildcard or blocked receiver exception is added. Redirect responses originate at that allowed fixture and target the still-blocked receiver. DNS answers use TTL zero: the controlled prevalidation request resolves to `172.24.0.2`, then the separate daemon resolver receives `172.24.0.3`; both answers were recorded. Prevalidation uses guard wget, not Briani's application resolver. Application SSRF tests are separate M04 evidence; this run proves the daemon namespace rejects the changed destination.

## Regression and limits

`python -m unittest discover -s tests/security -p 'probe_test.py' -v` exited **0**, six passed (`/tmp/briani-m10-egress-probe-unit2.log`). Checks prevent false zero-call acceptance, reject hits, preserve the baseline output and ensure negative observation rules cannot install a denial verdict.

Initial diagnostic run exited 1, preserved as `egress-extended-initial-invalid.json` and `/tmp/briani-m10-egress-extended.log`; it stopped at DNS setup. Its direct cases used test-created rejects and **are not production-policy acceptance evidence**. The corrected run removed that methodological confound, matched BEP19's appended filename for redirects, and enabled only the exact owned DNS source. All final cases were genuinely supported/exercised.

This extension proves IPv4/TCP daemon paths. It does not claim a separate UDP/uTP peer or IPv6 tracker/webseed run, physical Pi enforcement, arbitrary public DNS behavior, or release readiness. The existing baseline's loopback/IPv6/cloud/public controls remain their separately scoped evidence. Parent owns final policy integration, review and acceptance reconciliation.
