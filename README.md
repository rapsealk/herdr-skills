# herdr-skills

Claude Code skills for [Herdr](https://herdr.dev).

## foreman

Run one **foreman** agent in a local Herdr tab. It sends each job to the least-loaded saved
SSH machine, runs the job in its own remote tab, and reports progress back to that one tab.

```
local herdr                          remote machines (herdr --machine)
┌──────────────┐  dispatch    ┌──────────────────────────────┐
│ foreman tab  │ ───────────▶ │ workspace "foreman"          │
│ (claude)     │              │   tab job-train  (shell)     │
│              │ ◀─────────── │   tab job-fix    (claude)    │
└──────────────┘  status      └──────────────────────────────┘
```

Files:
- `.claude/skills/foreman/SKILL.md` — the foreman's instructions
- `.claude/skills/foreman/pick-machine.sh` — ranks enabled machines by load per core (over SSH)

### Requirements

- Herdr on local **and** on every remote, at versions that support machine API forwarding.
  Check with `herdr --machine <label> tab list`; if it fails, run `herdr update` on the remote.
- Remotes saved with `herdr machine add`, reachable via non-interactive SSH (key auth).
- `claude` installed and logged in on remotes, for agent jobs.
- `jq` locally.

### Install

The skill loads automatically when `claude` runs inside this repo. To use it from any
directory, also link it into your user skills:

```sh
ln -sfn "$PWD/.claude/skills/foreman" ~/.claude/skills/foreman
```

### Usage

1. Start `herdr`, open a tab named `foreman`, and run `claude` in it.
2. Ask for work:
   - `foreman: run "python train.py --epochs 10" in ~/proj` — a shell job
   - `foreman: have an agent fix the failing tests in ~/api` — an agent job

   Each job gets a remote tab `job-<slug>` and a confirmation line: `job-train → <machine>`.
   The foreman does not wait for a job to finish, so you can send many in a row.
3. Tracking starts by itself after the first job. Every 2 minutes the foreman prints:
   - what changed since the last report (`✓ job-train done: <summary>`)
   - a table of all jobs: name | machine | status | age | last line

   Finished, failed, and stuck jobs also show a Herdr notification. If a remote agent asks
   for approval, the foreman shows you the question and never answers it for you.
   The loop stops once nothing is running.
4. Other commands:
   - `foreman status` — report now
   - `foreman logs job-train` — last 200 lines of output
   - `foreman cancel job-train` — send Ctrl+C
   - `foreman clean` — close remote tabs of finished jobs (only tabs the foreman opened)

To watch a job live, select its machine in the Herdr TUI and open its `job-*` tab.

### State

Jobs are recorded in `~/.herdr-foreman/jobs.tsv` (machine, tab/pane IDs, status, original
request). If the foreman's `claude` session ends, the jobs keep running remotely; start
`claude` in the foreman tab again and it resumes tracking from the ledger.

### Limits

- Machines are ranked by CPU load only; add a GPU check in `pick-machine.sh` if needed.
- Tracking runs only while the foreman session is open.
