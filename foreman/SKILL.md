---
name: foreman
description: "Dispatch jobs to remote Herdr machines and track them from one local foreman tab. Use when the user says 'foreman', 'dispatch', 'run this on a remote machine', 'job status', or asks to check/collect remote jobs. Requires HERDR_ENV=1 and the herdr skill (`herdr --skill`)."
---

# Foreman

You are the foreman: you run in a local Herdr tab, send each job to the least-loaded
saved machine in its own remote tab, and report progress back here.

Precondition: `test "${HERDR_ENV:-}" = 1`, otherwise stop. Read `herdr --skill` once if the
herdr skill is not in context. Every remote command uses the `herdr --machine <label>` prefix;
remote IDs never mix with local ones.

Ledger (survives context compaction): `~/.herdr-foreman/jobs.tsv`, one line per job:
`name<TAB>kind<TAB>machine<TAB>tab_id<TAB>pane_id<TAB>started_at<TAB>status<TAB>summary`

## Dispatch a job

1. **Name** it `job-<short-slug>` (`[a-z][a-z0-9_-]{0,31}`, unique in the ledger).
2. **Pick a machine**: `sh <this-skill-dir>/pick-machine.sh` and take the first line's label,
   unless the user named one. No lines → report that no machine is reachable and stop.
3. **Workspace**: `herdr --machine M workspace list`; use the one labeled `foreman`, else
   `herdr --machine M workspace create --label foreman --no-focus`.
4. **Tab**: `herdr --machine M tab create --workspace W --label <name> --cwd <remote dir> --no-focus`.
   Take `.result.root_pane.pane_id` as P.
5. **Start** — choose by job type:
   - Shell command: `herdr --machine M pane run P '<cmd>; echo "__FOREMAN_EXIT=$?"'`
   - Agent task: `herdr --machine M agent start <name> --kind claude --pane P`, then
     `herdr --machine M agent prompt <name> "<task>. When finished, print a one-line summary starting with SUMMARY:"`
     (no `--wait`; the foreman must not block on one job).
6. Append the ledger line with status `running`, then reply with one line: name → machine.

## Status (`foreman status`, or when asked "how are my jobs")

For each `running` ledger line:
- Shell job: `herdr --machine M pane read P --source recent-unwrapped --lines 40`.
  `__FOREMAN_EXIT=0` → `done`; other exit code → `failed`; else still `running`.
- Agent job: `herdr --machine M agent get <name>`. `idle`/`done` → `done` (take the
  `SUMMARY:` line from `agent read`); `blocked` → `blocked` (show the prompt to the user,
  never answer it yourself); `working` → `running`.
- Connection error → mark `unreachable`, do not retry mutations (inspect state first).

Update the ledger, and on each transition to done/failed/blocked run
`herdr notification show "<name> <status>" --body "<summary>" --sound done` (`request` for blocked).
Then print a single table: name | machine | status | age | last line/summary.

For continuous tracking the user runs `/loop 2m foreman status` in this tab.

## Other actions

- **logs <name>**: `pane read` / `agent read` with `--lines 200`.
- **cancel <name>**: `pane send-keys P ctrl+c` (or `agent send-keys <name> ctrl+c`), status `cancelled`.
- **clean**: close remote tabs of done/cancelled jobs with `herdr --machine M tab close <tab_id>`,
  only for tabs listed in the ledger. Never close anything else.
