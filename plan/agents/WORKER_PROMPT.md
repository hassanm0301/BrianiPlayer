# Scoped worker prompt template

```text
ROLE: [worker/reviewer], [configured model and reasoning]
MILESTONE: [Mxx]
GOAL: [one bounded deliverable]
OWNED PATHS: [exact directories/files; edits elsewhere forbidden]
READ FIRST: AGENTS.md; [specific specification files/sections]; [contract symbols]
CONTRACT: [inputs, outputs, invariants and interface names]
ACCEPTANCE: [test IDs and exact observable behavior]
NON-GOALS: [adjacent features explicitly excluded]
BASELINE: [known test results, relevant versions, unresolved blocker]

Implement the deliverable and its focused tests. Treat other agents' changes as
owned work; do not overwrite them or edit shared contracts/lockfiles/migrations.
Ask the parent for a precise required contract change rather than guessing.
Do not spawn additional agents. Use generated/legal fixtures. Do not run
production operations, publish artifacts, or expose private services.

Return: changed paths; implemented behavior; commands and exit codes; evidence
paths; unresolved failures; and any proposed contract change. Keep the handoff
under 700 words, with full logs saved to files. Never claim a test/agent/hardware
run that did not happen.
```

For read-only reviewers, replace implementation instructions with: inspect the actual changed code and tests; return concrete defects by severity with path/symbol, reproduction, impact and suggested minimal correction. Do not edit files or request style-only rewrites.
