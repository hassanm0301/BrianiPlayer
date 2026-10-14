# M10 manage-only download control review

2026-10-13. Independent read-only source review of `DownloadAccess.cs`, `DownloadCommands.cs`, `DownloadWorker.cs`, `FinalAcceptanceTests.cs`, and the required permission/admission/administration boundaries. Only this report was written. No tests, builds, Docker, Pi/SSH, hardware, or production operations were executed. Root owns production integration and the test worker owns execution evidence.

**Current source result: no open P1/P2 finding remains in the reviewed correction.** Historical findings, corrections, and the exact execution limits are retained below. Integrated regressions after the final quota change are the parent's remaining verification work.

## Permission behavior confirmed

`DownloadAccess.RequireCommandAsync` independently accepts current read+manage for existing lifecycle controls, including a foreign request, while `add` still requires download permission. `DownloadCommands.CreateAsync` requires download before source resolution and again under WriteGate before durable admission. Current capabilities read the live library, session, enabled user/role, password-change state, and grant; stale Actor.Role does not bypass these checks. Read-only/offline/disabled libraries fail closed for manage/download.

An ordinary download owner can detach its own request without deleting shared payload and can attach a compatible shared selection without changing transfer priorities. Foreign/shared destructive lifecycle control still needs manage. Compatible selection still validates IDs/types/priorities and quotas; it does not grant arbitrary paths or new-source permission. Submitted worker operations record the acting user/session rather than relying on the request owner's privileges. New-source and queued-work revocation cases in `FinalAcceptanceTests` exercise these distinctions. The original manager-resume fixture lacked its owner's download grant; the worker added that grant so the test measures manager control rather than an unrelated reservation failure.

## Findings sent to root

**P1 — missing reauthorization between awaited engine effects.** Initial `ApplySelectionAsync` checked once after StopSettled, then ran multiple priority groups and sequential/metadata-assist effects; shared `RemoveAsync` likewise reused one check for multiple priority groups and catalog removal. Revocation during the first held engine call could permit later effects. Root added fresh callbacks before every group, sequential/assist, add-time managed limits, removed-request catalog changes, and metadata cache/retirement changes. Those edits close the observed source schedules. A held-priority/revocation regression is being added by the test owner; the prior queued-before-worker test did not exercise a mid-await boundary.

**P1 — final start used authorization from before reservation waiting.** `ApplySelectionAsync` checked before awaiting `RequireReservationsAsync`, which waits on WriteGate and initially consumed the original library snapshot. Manager revocation or ReadOnly changes during that wait could be followed by Start without a fresh actor check. Root plans a callback immediately after reservations/before Start, plus a live library read inside reservations for both explicit and background starts. Pending correction review.

**P2 — denied foreign-manager work poisoned the owner's job state.** The generic worker catch set `DesiredState="stopped"` and request/job errors even when current manager authorization was denied. PollOnce could then stop valid owners after the immediate worker test observed no Stop call. Root plans to retain the pre-command desired state in the internal optional journal payload, restore it for authorization rejection, and fail only the operation rather than marking the owner's request/job failed. Capture the original state under WriteGate before mutation, preserve old-journal compatibility, and do not overwrite a newer/retired state. Partially applied selection effects still require conservative availability fencing; prior authorization does not make an inconsistent layout safe to restart automatically.

**P2 — shared attachment could race the control authorization snapshot.** `RequireControlAsync` determines whether other requests exist before awaited capability reads; Create previously attached an existing job under WriteGate without the job lock held by control work. A new attachment could change shared status inside that interval. Root plans to acquire the existing job lock before WriteGate, loop/recheck its identity after acquiring the gate, and recheck grants/idempotency there. The no-existing→existing, retirement/hash-change, and same-key cases must release WriteGate before waiting on a job lock to preserve the established lock order. Pending correction review.

## Evidence limits

Source-level findings and fixes above are not executed reproductions or test passes. The held-effect, readonly, shared-selection/removal, and later-poll checks belong to the owner's focused regression run, followed by relevant integrated suites. Existing assertions cover read/manage visibility combinations, manage-only settings/pause/resume, new-source denial, queued grant revocation, readonly denial, and retained payload after removal; a test titled shared-data removal must actually attach another request to establish shared lifecycle behavior.

This review does not establish native platform support, hardware verification, branch coverage, or release readiness. Targeted reads succeeded apart from initial guessed nonexistent PermissionService file paths; the actual implementation in `Infrastructure/Security/Policy.cs` was then read. No runtime results were fabricated. Final correction inspection remains pending.

## Correction inspection

Reinspected the integrated corrections: each awaited priority/sequential/assist/control boundary gets a current authorization callback; Start now checks again after reservations. Reservations reload current library flags inside WriteGate. `CreateAsync` releases WriteGate before taking the existing job lock, then reacquires the gate, clears tracking, and rechecks hash/job identity, download grant, and idempotency, with a four-attempt bound. New-source admission still requires download.

The internal optional `PreviousDesiredState` is captured before state mutation under the gate and excluded from the user idempotency digest. Worker authorization rejection preserves it only for a foreign acting user when all request owners remain authorized. Owner-grant/user revocation retains the prior fail/stopped behavior; nonretired checks and conservative legacy fallback remain. This closes the reported indirect foreign-manager polling effect without treating genuine owner revocation as harmless. Availability fencing is retained for interrupted partial mutations.

The test owner added real held priority calls, revocation while retaining the actor's download permission, unchanged RemovedAt after shared removal rejection, foreign-denial follow-up polling, and an attachment blocked behind the existing job lock. Parent reports focused 8/8 and complete DownloadTests 106/106 passed, including the earlier owner revocation regression. No reviewer execution is claimed.

**Remaining P2 — foreign control admission charges the wrong user.** `DownloadCommands.SubmitAsync` passes the acting manager to `admission.RequireAsync` for selection (line 99 at inspection), while ownership rows/selected bytes are attributed to `request.OwnerId` (line 101). `DownloadAdmission.cs:28–48` computes quota using the supplied Actor.UserId; worker reservations already use each request owner. Thus a small manager quota wrongly rejects a valid owner's selection, while an unlimited manager can enqueue an owner-over-quota selection before the worker rejects it. Charge the request owner for selection/retry reservations while retaining separate manager authorization. This is a concrete source mismatch in an existing foreign-control path, now relevant to the manage-only correction; it was sent to root before rebuilding. Its fix/regression is pending.

## Final quota correction closure

The quota finding is now closed in source. `SubmitAsync:88–109` builds a reservation-only Actor from `request.OwnerId` and passes it to both selection and retry admission. The actual acting manager still passes the separate live control authorization; Create continues charging its actual new request owner. `DownloadAdmission` uses only that reservation Actor's UserId for attribution, so the empty session/member role does not bypass permission checks or alter the manager operation identity.

The test owner added a two-case `Foreign_manager_selection_quota_is_attributed_to_request_owner` theory: owner budget with a tiny manager budget is accepted, while an over-quota owner with an unlimited manager is rejected before queuing. Final execution after this edit was pending at this inspection. Parent reports the preceding full solution run passed 410 tests; that is explicitly before the quota correction and does not substitute for the upcoming rerun.

Reviewed production snapshot SHA256:

```text
DownloadAccess.cs   4df9f04f8ca7970c821bf103e81232b0c8d2daa5281bbe909ff3d690cf68e624
DownloadCommands.cs 57f69e3cf8b17b8fc610aa7f6e270d609be8937ed918ab7a40007b5847107f89
DownloadWorker.cs   bd480876385490e7d5020d8c01df6cc301f88f3528583389425b5b86765f8e49
```

No further source defect was identified within the changed boundary. This conclusion is scoped to manage-only controls, current authorization at later effects, shared attachment serialization, denial-state isolation, and owner quota attribution. Parent owns final test/build/artifact regeneration evidence; no release or hardware certification is issued.
