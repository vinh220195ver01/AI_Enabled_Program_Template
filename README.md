# AI_Enabled_Program_Template

Starter kit for trainees.

- `exercises/` — one folder per exercise, each with a `BRIEF.md` (see `exercises/README.md`).
- `memory/` — your agent's memory is copied here when you submit an exercise.
- `.claude/skills/submit-exercise/` — the last step of every exercise: `/submit-exercise <exercise name>`.
- `.claude/skills/exercise-agent/` — template for the agent that guides one exercise and ends with the submit step.
- `.claude/hooks/` + `.claude/settings.json` — governance guard (see below); rules in `governance-rules.txt`.

## Data notice
`/submit-exercise` copies your agent's **local memory** (Claude Code:
`~/.claude/projects/<this repo>/memory`, or the folder in `$MEMORY_SOURCE_DIR`) into
`memory/` and commits it **raw and unfiltered** on your current branch with your
exercise work. The submit itself happens only when you run the command, and it prints
every file it commits. Push is a separate step you decide on.
Do not keep real passwords, keys or personal data in your memory. If the repo is public,
what you push is public.

## Governance guard
Hooks (`.claude/settings.json`) apply the *AI-Enabled QA Governance* register v0.1. They never
block you; they **record** findings in `governance-checklist.md`, a table with one row per
finding (when, severity, where, rule code, issue, what to do; tick `[x]` when handled):
- Before each prompt: your input is scanned (the prompt text only). Secrets, keys, connection
  strings and card numbers (digit runs that pass the Luhn check) are logged as a **VIOLATION** (escalate, AR-06). Restricted or unlisted tools, confidential or
  production data and risky behavior are logged as **NEEDS REVIEW** (not an automatic fail).
- When the agent finishes: its local memory is scanned the same way, and so are the repo files
  that are changed, untracked or in unpushed commits (scripts included; `.claude/hooks/`,
  `.claude/skills/`, `memory/`, the template docs and binary files are skipped). Only files
  that changed since the last run are scanned. A finding is recorded once per file and rule
  while it stays flagged; fix it and a later reappearance is recorded again. The file path is
  recorded, never its content. Scan state is kept in `.git/governance-state` (never pushed).
- Rows from prompts are committed at the next Stop, together with the rest.
- Right after, `governance-commit.sh` commits only `governance-checklist.md`. Other staged files
  are not touched. It never pushes: the checklist commit reaches the remote with your own push.
- Input findings are recorded once per rule per day.
Only the rule ID, source and file name are written, never the matched text. The scan is
pattern-based, a safety net and not a guarantee. Tune it in `.claude/hooks/governance-rules.txt`.
