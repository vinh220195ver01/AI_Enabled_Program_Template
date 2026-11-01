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
After every commit, two things happen:
1. memory/ is scanned for secrets/personal data/unsafe instructions; the result
   (no secret values) is appended to safety-log/safety-log.jsonl, a hash-chained log.
2. Only if the scan PASSES, memory/ contents are pushed (raw, unfiltered) to branch memory-backups/<your git name> on the remote,
for evaluating AI safety gates in this course. Each run prints a message;
backups are also logged to memory-backup.log.
If the scan FAILS nothing is pushed; fix the memory entry and commit again.
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
