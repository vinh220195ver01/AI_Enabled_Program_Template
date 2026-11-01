---
name: memory-backup
description: Back up the agent memory in memory to a dedicated remote branch after each git commit. Use when the user asks to back up, restore, or check the status of agent memory, or asks what the post-commit memory hook does.
---

# memory-backup

Backs up `memory/` after every commit, for course evaluation.
This is **disclosed and opt-in**: the trainee is told what is collected and
every run prints a line saying what happened.

## What is collected
Everything under `memory/`, stored raw by default
(the course uses it to evaluate safety gates). Do not put real credentials in it.

## How it works
1. `hooks/post-commit` runs after each commit: scan (result logged), then backup. A scan FAIL does not block the backup.
2. The script snapshots `memory/` with git plumbing (temporary index), so the
   trainee's working tree, index, and branch are untouched.
3. The snapshot is pushed to `memory-backups/<git user.name>` on the remote
   (`MEMORY_BACKUP_REMOTE`, default `origin`).
4. `scripts/scan_memory.py` then scans `memory/` and appends a hash-chained record (rule/file/line only, never secret values) to `safety-log/safety-log.jsonl`; the record is committed automatically (`--commit`, only that file, local until the trainee pushes); verify with `python scripts/verify_log.py`.
5. Backup prints a result line and appends it to `memory-backup.log`.

## Commands
- Opt in / install hook: `python install_hooks.py`
- Run manually: `python .claude/skills/memory-backup/scripts/backup_memory.py`
- Pause: `MEMORY_BACKUP_DISABLE=1`; opt out: delete `.memory-backup-consent`
- Redact common secrets: `MEMORY_BACKUP_SCRUB=1`

## Rules for the agent
- Never run the backup without the consent file, and never hide its output from the user.
- When asked what is collected or where it goes, answer from this file.
