# AI_Enabled_Program_Template

Starter kit for trainees of the AI-Enabled QA program. Works with any AI tool (Claude Code,
GitHub Copilot, Cursor, Antigravity, ...).

| Path | What it is |
|---|---|
| `exercises/` | one folder per exercise, each with a `BRIEF.md` (see `exercises/README.md`) |
| `AGENTS.md` | instructions every AI agent follows in this repo (governance, finishing an exercise) |
| `CLAUDE.md` | Claude Code entry point; loads `AGENTS.md` |
| `.github/copilot-instructions.md` | points GitHub Copilot to `AGENTS.md` |
| `.claude/skills/exercise-agent/` | template for an agent that guides one exercise |
| `.claude/settings.json`, `.claude/hooks/` | governance guard (rules in `governance-rules.txt`; `governance-note.ps1` runs it from PowerShell) |
| `.githooks/pre-commit` | governance scan on every commit, whatever tool makes it |

## Setup (once, after you clone your repo)
Turn on the commit scan, whatever AI tool you use:

    git config core.hooksPath .githooks

You need Git (on Windows, Git for Windows, which includes Git Bash). Nothing else.

## Doing an exercise
1. Create `exercises/<exNN>-<short-name>/BRIEF.md` from `exercises/_template/BRIEF.md`.
2. Work on it with your AI agent, using synthetic or masked data only.
3. When the "Done when" criteria are met, commit the folder:
   `git add exercises/<exNN>-<short-name>` and `git commit`.
4. Push when you decide to: `git push -u origin HEAD`. If the repo is public, what you push
   is public.

Do not keep real passwords, keys or personal data in your agent's memory either: the
Claude Code hooks scan it (see below).

## Governance guard
The guard applies the *AI-Enabled QA Governance* register v0.1. It never blocks you: it
**records** findings in `governance-checklist.md`, a table with one row per finding (when,
severity, where, rule code, issue, what to do; tick `[x]` when handled). Only the rule code,
the source and the file name are written, never the matched text.

| Layer | Works with | Scans | Reliability |
|---|---|---|---|
| Claude Code hooks (`.claude/settings.json`) | Claude Code only | prompts, agent memory, changed files | automatic |
| `AGENTS.md` + `governance-guard.sh note <CODE>` | AI agents that can run commands | prompts (the agent checks them) | best effort: an agent can miss one |
| git `pre-commit` (`.githooks/`) | any tool, once enabled (see Setup) | the staged files of each commit | automatic, unless bypassed with `--no-verify` |

No layer can scan what you paste into a web chat that has no access to this repo: use
synthetic data only.

**Severity.** Secrets, keys, connection strings and card numbers (digit runs that pass the
Luhn check) are a **VIOLATION** (escalate, AR-06). Restricted or unlisted tools, confidential
or production data and risky behavior are **NEEDS REVIEW** (not an automatic fail).

**Claude Code hooks.**
- Before each prompt: the prompt text is scanned. A rule is recorded once per day.
- When the agent finishes a turn: the agent's local memory and the repo files that are
  changed, untracked or in unpushed commits are scanned (only files changed since the last
  run; the guard, the template docs and binary files are skipped). A finding is
  recorded once per file and rule while it stays flagged; fix it and a later reappearance is
  recorded again. Scan state is kept in `.git/governance-state` (never pushed).
- Then `governance-commit.sh` commits `governance-checklist.md` alone (your other staged files
  are not touched).

**Agent notes.** An agent that notices sensitive data in your message runs
`bash .claude/hooks/governance-guard.sh note <CODE>` (or `governance-note.ps1` from
PowerShell). Only the rule code is recorded, once per code per day; the row says
"Prompt (reported by the agent)". The checklist is then committed alone.

**Commit scan.** Every `git commit` scans the staged content and adds the checklist to that
same commit. A file and rule already listed is not recorded again.

Nothing in the guard pushes: checklist commits reach the remote with your own push.

**Notice for trainees:** these findings are recorded as part of the program's governance
process. To keep the chat uncluttered, the agent records a finding without announcing the rule
code each time and just reminds you to use masked or synthetic data. Nothing is hidden:
`governance-checklist.md` is a normal file in this repo, committed with your work, and you can
open it at any time. If you ask the agent whether something was recorded, it will tell you.

The scan is pattern-based, a safety net and not a guarantee. Tune it in
`.claude/hooks/governance-rules.txt`.
