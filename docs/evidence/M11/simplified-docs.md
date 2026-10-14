# Documentation simplification — 14 October 2026

The user requested a simpler self-hosting guide. The parent shortened `docs/operations/README.md` from 395 to 108 lines and reduced the root README to 21 lines. The main server guide now presents five steps: load supplied images, choose folders/address, start services, connect a client/create the administrator, and add media. Actual required image locks, host checks, first-run credential ordering, and HTTP opt-in remain in the instructions. This is a documentation follow-up to M11, contributing the instructions associated with R01/R03/R26 and T25/T27/T30 without promoting those gates.

The previous detailed guide is preserved as `docs/operations/advanced.md`, linked for Prowlarr administration, backups, restore, upgrades, service controls, and troubleshooting. `docs/user-guide.md` points to the new administrator section. The existing documentation validator now checks the advanced guide as well as the five original documents and validates both sets of CLI examples. The parent owned all edits. No implementation worker was launched for this small editorial change.

A separate read-only GPT-6 Luna/medium reviewer checked the shortened instructions against the operations tool and Compose files. Two clarifications were integrated: first startup needs registry access for the pinned qBittorrent/Prowlarr images, and the text names which command stores each service credential. Review found no startup-order, image-tag, gate-bypass, or anchor defect. The documentation check passed again after these corrections.

| Command | Exit | Evidence |
|---|---:|---|
| `python3 docs/evidence/M11/self-hosting-docs/validate_docs.py` | 0 | `simplified-docs/docs-check.log`: six documents, 34 links/anchors, 31 shell blocks, 21 operations-parser examples, four Compose identity cases |
| `python3 -m unittest discover -s tests/operations` | 0 | `simplified-docs/operations-tests.log`: 26 tests |
| `python3 -m unittest discover -s tests/release` | 0 | `simplified-docs/release-tools-tests.log`: 57 tests |
| `sha256sum -c --quiet dist/SHA256SUMS` | 0 | `simplified-docs/checksums.log`: 843 original entries verified; empty log indicates quiet success |
| `python3 tools/dev.py release --task verify` | 2 | `simplified-docs/release-verify.log`: source-tree snapshot mismatch; runner logs in `artifacts/dev/20261013T214400.044491Z/` |

No server/client code, contracts, locks, binary packages, security requirements, or production configuration changed. No deployment, signing, publication, router change, or real indexer setup occurred. Full application and hardware suites were not rerun for this documentation-only edit. Existing verification blockers remain in `plan/evidence/status.json`; an additional documentation entry records this work. The original `dist/` archives remain unchanged and therefore contain their prior documentation/source snapshot; release verification correctly reports that mismatch. Future packaging must incorporate these docs and regenerate matching provenance. There is no new implementation milestone assigned by this request; the user-facing starting point is the shortened Docker guide.
