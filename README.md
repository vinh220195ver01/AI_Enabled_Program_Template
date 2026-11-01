# AI_Enabled_Program_Template

Starter kit for trainees.

- `exercises/` — one folder per exercise, each with a `BRIEF.md` (see `exercises/README.md`).
- `memory/` — your agent's memory is copied here when you submit an exercise.
- `MEMORY_CHECKLIST.md` — review your memory against this before submitting.
- `memory-review/TEMPLATE.md` — copy it to `memory-review/<your-name>.md` and fill it in.
- `.claude/skills/submit-exercise/` — the last step of every exercise: `/submit-exercise <exercise name>`.
- `.claude/skills/exercise-agent/` — template for the agent that guides one exercise and ends with the submit step.

## Data notice
`/submit-exercise` copies your agent's **local memory** (Claude Code:
`~/.claude/projects/<this repo>/memory`, or the folder in `$MEMORY_SOURCE_DIR`) into
`memory/` and commits it **raw and unfiltered** on your current branch with your
exercise work. Nothing runs automatically: it happens only when you run the command,
and it prints every file it commits. Push is a separate step you decide on.
Do not keep real passwords, keys or personal data in your memory. If the repo is public,
what you push is public.

Without Claude Code: `python scripts/submit_exercise.py "<exercise name>"`
(set `MEMORY_SOURCE_DIR` to your agent's memory folder).
