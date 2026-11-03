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
block you; they **record** findings in `governance-checklist.md` as open checkboxes:
- Before each prompt: your input is scanned. Secrets, keys, connection strings and card numbers
  are logged as a **VIOLATION** (escalate, AR-06). Restricted or unlisted tools, confidential or
  production data and risky behavior are logged as **NEEDS REVIEW** (not an automatic fail).
- When the agent finishes: its local memory is scanned the same way (one entry per file and rule).
- Right after, `governance-commit.sh` commits only `governance-checklist.md` and pushes. Other
  staged files are not touched. If the push fails, it is retried at the next run.
Only the rule ID, source and file name are written, never the matched text. The scan is
pattern-based, a safety net and not a guarantee. Tune it in `.claude/hooks/governance-rules.txt`.
