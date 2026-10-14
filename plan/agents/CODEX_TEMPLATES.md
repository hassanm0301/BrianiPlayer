# Optional Codex configuration templates

The TOML files in this directory are templates to copy into repository `.codex/` after checking the installed Codex version and available models. They are not active automatically inside `plan/agents/`.

- Copy `config.toml.example` to `.codex/config.toml`, merging rather than overwriting existing configuration.
- Copy `briani_worker.toml.example`, `briani_protocol.toml.example`, `briani_reviewer.toml.example` into `.codex/agents/`, removing `.example`.
- The parent is selected in the Codex session as GPT 6.1 Sol high; these templates govern workers.

The documented configuration used as reference was checked 12 October 2026 (S22). Runtime support may differ. Validate configuration with the installed tool before use; do not downgrade sandbox/approval policy just to make an agent run. In particular, do not copy an unsupported key blindly.

Expected policy is maximum three active worker/review threads, ordinarily two implementation workers and one read-only review. Some tool versions use legacy naming for concurrency settings; use the supported form from that installed version rather than two conflicting aliases.
