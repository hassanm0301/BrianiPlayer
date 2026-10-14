# M02 — Implement accounts, sessions, grants and safe filesystem boundaries

**Execution model:** GPT 6.1 Sol / high parent. **Prerequisites:** M01 complete.

This is an implementation work package, not a request for another plan. Follow repository-root AGENTS and `plan/agents/EXECUTION_PROTOCOL.md`. Inspect the actual repository and previous evidence before editing. Each task below must become working code, tests or genuine evidence; prose describing an implementation is not completion.

## Required reading and ownership

Read the following package inputs, only expanding unrelated documents when a dependency requires it: 01_PRODUCT.md, 03_DATA_MODEL.md, 07_SECURITY.md, 12_API_CONTRACT.md; relevant auth/user/library schemas. Paths without a directory prefix above are under `plan/specs/`. Read the relevant OpenAPI/default sections and previous milestone handoff. The parent owns shared contracts, migrations, application composition, dependency locks and final integration. Delegate disjoint paths; workers cannot silently change these shared contracts.

## Bounded subagent assignments

**Parent — Sol high:** own authentication/session design, migrations, filesystem containment and authorization policy.
**Worker A — Luna medium:** administrator user/grant handlers and typed validation in `server/Modules/Administration/`, using the frozen policy interface.
**Worker B — Luna medium:** table-driven permission/session tests in `tests/Identity/`; do not change implementation to make negative tests pass.
**Reviewer — Sol high:** independent auth, pairing, token, traversal and symlink review.

Use at most two implementation workers concurrently. Give each the exact input sections, allowed files, tests and non-goals from the worker template. No recursive agents and no duplicate full-repository exploration. The parent integrates and validates rather than redoing every worker's code. If no subagent capability exists, execute these assignments serially and record that fact.

## Ordered implementation tasks

1. Implement one-time bootstrap using the generated expiring secret and transactional first-admin creation. No public registration and no race in which an unauthenticated caller becomes administrator. Protect last-enabled-admin invariants.
2. Implement framework password hashing, opaque random access/refresh tokens, hashed token persistence, refresh rotation/replay response, logout, password change/reset, user disable and own-session revocation. Apply explicit rate limits and generic login failures; redact all credentials.
3. Add administrator CRUD and library grant APIs. Read/download/manage are independent except download requires read. Evaluate effective authorization centrally for each request, not only in UI. Define ownership-aware download policy for later modules.
4. Implement TV device pairing: random private device secret plus short human code, five-minute expiry, bounded polling, authenticated approval for the approving account, one-time exchange and replay/rate-limit defenses. Login remains available as fallback.
5. Implement configured storage roots and the contained filesystem abstraction. Reject overlapping libraries, traversal, symlinks/reparse-like escapes, invalid path normalization and path races. Use descriptor-relative safe operations on the Linux server; do not rely on string-prefix comparisons. Preserve legitimate Unicode names and large offsets.
6. Wire secret/reference handling and secure settings storage. Keep upstream credentials inaccessible to ordinary API clients. Define uniform not-found/forbidden behavior that avoids exposing another user's library or active download location.
7. Add audit events for user/grant changes and bootstrap/auth events without logging raw codes/tokens/passwords. Validate UTC/fake-clock handling, token expiration and revocation during an open long-lived request through a test seam.
8. Implement a minimal authenticated API integration story using two users and two libraries, then run adversarial permission/containment tests. Frontend polished administration can wait; API security cannot.

## Acceptance and execution

Required scenarios: **T15, T16, T18, T31; authorization fixtures reused by later milestones.** Definitions are in specification 09; they are not optional examples.

Run `python tools/dev.py build`, `test --suite unit`, `test --suite identity`, `test --suite contract`; add the identity suite to the runner. Include a SQLite-backed integration run and a Linux symlink-swap adversarial test, not only mocked paths.

Commands specified here are repository commands to implement where not yet present, not tools claimed to already exist in this planning package. Extend the task runner with explicit suites; do not turn a missing suite or prerequisite into a zero-exit success. Use deterministic fixtures and fake clocks for unit timing, with actual external components for integration gates.

## Deliverables

Account/session/pairing/grant APIs, authoritative containment and permission services, migrations, audit events, negative test matrix and reviewer findings with fixes.

Write `docs/evidence/M02/report.md` using the report template, include commands/exit codes/versions/log paths, and add an independent review section. Update `plan/evidence/status.json` with code and verification states. Return a 300–700-word handoff with changed paths, tests, findings and next milestone, not the entire logs. Preserve unrelated user changes and do not publish/deploy without authorization.

## Boundaries and continuation

Do not expose discovery to members with no download-capable library. Do not add SSO/cloud accounts, e-mail infrastructure or a custom cryptographic algorithm. M03 cannot bypass this filesystem abstraction for convenience.

A model/context limit is handled by writing a checkpoint and evidence, not by silently dropping work. An external environment blocker is stated exactly; continue independent tasks when safe, but never mark blocked checks passed. Do not reopen decided product scope to avoid a difficult implementation.
