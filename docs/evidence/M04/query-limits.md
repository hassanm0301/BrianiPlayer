# M04 discovery query resource limits

These limits bound durable discovery state and private source-resolution data. They are enforced when a new snapshot or idempotency operation is created; an idempotent replay or an eligible cache hit reuses its existing snapshot and does not consume another snapshot slot.

| Resource | Limit | Accounting |
| --- | ---: | --- |
| Retained discovery snapshots | 64 per user; 256 total | All rows count until the discovery housekeeper removes them, including expired rows awaiting the cleanup grace period. |
| Retained discovery idempotency operations | 256 per user; 4,096 total | Discovery query operations count until housekeeper deletion. Existing-key replays and in-place reuse of an expired operation do not add rows. |
| Results retained by one snapshot | 500 | Additional unique results mark the snapshot truncated; duplicate compatible torrent hashes continue to merge. |
| Encrypted source alternatives per result | 100 maximum and 32 KiB maximum UTF-8 serialized plaintext | An oversized alternative is omitted with a safe warning. A first option that itself exceeds the byte cap is not made downloadable. |

Limit rejections use HTTP 429 with `discovery_snapshot_limit` or `discovery_operation_limit`. Query creation remains asynchronous, and these limits do not change provider concurrency or upstream request behavior.

Focused acceptance tests exercise the per-user snapshot and operation caps, cached and idempotent reuse at capacity, 500-result truncation, and omission of an oversized merged alternative. The global caps are implemented by counting retained rows under the discovery write gate; they are not stress-tested at the full row counts in this handoff.
