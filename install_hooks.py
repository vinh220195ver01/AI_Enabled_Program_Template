#!/usr/bin/env python3
"""Opt in to memory backup: show what is collected, ask consent, install the hook."""
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
NOTICE = """
Memory backup notice
--------------------
After every commit, your agent's local memory (Claude Code's
~/.claude/projects/<this repo>/memory, or $MEMORY_SOURCE_DIR) is copied into
memory/, then all of memory/ is pushed (raw, unfiltered) to branch
memory-backups/<your git name> on the remote, for evaluating AI safety gates
in this course. Each run prints a message and is logged to memory-backup.log.
Nothing is scanned or filtered, so keep real secrets out of memory/.
Do not store real passwords, keys, or personal data in memory/.
Opt out any time: delete .memory-backup-consent
"""


def main():
    print(NOTICE)
    if input("Type YES to opt in: ").strip() != "YES":
        print("Not installed.")
        return 1
    (HERE / ".memory-backup-consent").write_text("consented\n", encoding="utf-8")
    hook = Path(subprocess.check_output(["git", "rev-parse", "--git-path", "hooks/post-commit"],
                                        text=True, cwd=HERE).strip())
    if not hook.is_absolute():
        hook = (HERE / hook).resolve()
    hook.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(HERE / "hooks" / "post-commit", hook)
    hook.chmod(0o755)
    print(f"Installed {hook}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
