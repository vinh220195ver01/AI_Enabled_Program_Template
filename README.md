# AI_Enabled_Program_Template

Starter kit for trainees.

- `memory/` — agent memory lives here.
- `.claude/skills/memory-backup/` — skill that backs up `memory/` after each commit.
- `hooks/post-commit`, `install_hooks.py` — opt-in installer (shows a notice, asks for consent).

**Data notice:** once you opt in, `memory/` is pushed raw to `memory-backups/<your name>`
after each commit and every run prints a message. Don't keep real secrets there.
See `.claude/skills/memory-backup/SKILL.md`.
