# Instructions for continuing this project

Read `HANDOFF.md`, `docs/TASKS.md`, `docs/DECISIONS.md`, then `docs/START_HERE.md` and the relevant source before changing behavior. This file is the single rules file for every agent (Codex reads it directly; Claude Code reads it via `CLAUDE.md`). The docs are a handoff record, not a substitute for checking the current machine and current code.

- Keep the MVP local, read-only, and without a game UI. Do not add memory access, input automation, or cloud databases. A read-only MCP server is approved (see `docs/DECISIONS.md` D1); any public endpoint or tunnel still needs explicit user approval (D4).
- Preserve Chinese names and Forever version specificity. Do not substitute Retail/Classic Era assumptions for verified Forever behavior.
- The user prefers execution over repeated permission questions, and no manual copying/uploading. Act within authorization; explain concrete authentication or environment blockers.
- Keep real game tests distinct from mock tests. Historical snapshots are not live context, even if their saved freshness says otherwise.
- Do not commit raw chat logs, credentials, PID files, runtime output, or Python environments. The repository is prepared for public release: never commit real character data (names, live snapshots), local absolute paths, chat IDs or emails. Test data goes in `tests/fixtures/` with identities removed. Do not add automatic snapshot uploads.
- Check both `freshness` and the age of `capturedAt`, plus `capabilities`, `errors`, and `questLogMayBeIncomplete` before using a snapshot for advice. When the user asks for gameplay advice ("what next"), follow `docs/ADVISOR.md`.
- Do not terminate a process solely because its PID matches an old file; verify its executable and command line first.
- A checkout is not an installed addon. Changing Lua on disk does not prove the running game has loaded it. Record the reload/restart requirement and validate the loaded behavior.
- Update handoff, implementation status, and validation docs when behavior or evidence changes. Do not silently promote planned work into completed work.
- The user writes in Chinese and English. User-facing docs are bilingual: `README.md` / `INSTALL.md` (English) and `README.zh-CN.md` / `INSTALL.zh-CN.md` (Chinese); change both together. Developer docs in `docs/` stay in Chinese. Reply in the language the user used. Keep exact code/API identifiers.
- Committing and pushing directly to `main` is allowed for this personal repo (D5). Do not force-push. This repository is public: commit as `polopineapplem <4616752+polopineapplem@users.noreply.github.com>`, never with a real name or machine hostname (D16).

## Session-end rule (required)

Before ending any session that changed code, docs, or evidence:

1. Update `docs/TASKS.md`: move task status, add newly discovered tasks, keep the date.
2. Rewrite the "当前状态" section of `HANDOFF.md`: what changed, what was verified (and how: real game vs mock), the exact next step.
3. Append any new decision to `docs/DECISIONS.md` (dated, with reason). Never silently reverse an earlier decision.
4. Commit and push, so the next session on any machine sees it.

No sub-agent delegation is required by this file. Do not commit unrelated machine configuration.
