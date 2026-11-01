#!/usr/bin/env python3
"""Back up memory to a dedicated branch and push it.

Runs after each commit (see hooks/post-commit). It never touches the
trainee's working tree, index, or current branch: it builds a snapshot commit
with git plumbing and a temporary index, then pushes that to
`memory-backups/<user>` on the configured remote.

Always prints what it did. Does nothing without a consent file.

Env:
  MEMORY_BACKUP_REMOTE   remote name (default: origin)
  MEMORY_BACKUP_DISABLE  set to 1 to skip
  MEMORY_BACKUP_SCRUB    set to 1 to redact common secret patterns first
"""
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

TEMPLATE = Path(__file__).resolve().parents[4]
MEMORY = TEMPLATE / "memory"
CONSENT = TEMPLATE / ".memory-backup-consent"
LOG = TEMPLATE / "memory-backup.log"
SECRET = re.compile(r"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*\S+")


def git(*args, env=None, cwd=None):
    r = subprocess.run(["git", *args], capture_output=True, text=True, env=env, cwd=cwd)
    if r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r.stdout.strip()


def say(msg):
    line = f"[memory-backup] {msg}"
    print(line)
    with LOG.open("a", encoding="utf-8") as f:
        f.write(f"{datetime.now(timezone.utc).isoformat()} {msg}\n")


def main():
    if os.environ.get("MEMORY_BACKUP_DISABLE") == "1":
        print("[memory-backup] disabled via MEMORY_BACKUP_DISABLE")
        return 0
    if not CONSENT.exists():
        print("[memory-backup] skipped: no consent file. Run install_hooks.py to opt in.")
        return 0
    files = [p for p in MEMORY.rglob("*") if p.is_file()]
    if not files:
        print("[memory-backup] memory/ is empty, nothing to back up")
        return 0

    root = Path(git("rev-parse", "--show-toplevel"))
    remote = os.environ.get("MEMORY_BACKUP_REMOTE", "origin")
    user = re.sub(r"[^\w.-]", "_", git("config", "user.name") or "unknown")
    ref = f"refs/heads/memory-backups/{user}"
    scrub = os.environ.get("MEMORY_BACKUP_SCRUB") == "1"

    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "GIT_INDEX_FILE": str(Path(tmp) / "index")}
        for p in files:
            rel = p.relative_to(root).as_posix()
            if scrub and p.suffix in {".md", ".txt", ".json", ".yaml", ".yml"}:
                text = SECRET.sub(r"\1: [REDACTED]", p.read_text(encoding="utf-8", errors="ignore"))
                blob = subprocess.run(["git", "hash-object", "-w", "--stdin"], input=text,
                                      capture_output=True, text=True, cwd=root).stdout.strip()
            else:
                blob = git("hash-object", "-w", str(p), cwd=root)
            git("update-index", "--add", "--cacheinfo", f"100644,{blob},{rel}", env=env, cwd=root)
        tree = git("write-tree", env=env, cwd=root)

    parent = subprocess.run(["git", "rev-parse", "--verify", "-q", ref],
                            capture_output=True, text=True, cwd=root).stdout.strip()
    if parent and git("rev-parse", f"{parent}^{{tree}}", cwd=root) == tree:
        say("memory unchanged since last backup, nothing pushed")
        return 0
    args = ["commit-tree", tree, "-m", f"memory backup {datetime.now(timezone.utc):%Y-%m-%d %H:%M}Z"]
    if parent:
        args += ["-p", parent]
    commit = git(*args, cwd=root)
    git("update-ref", ref, commit, cwd=root)
    try:
        git("push", remote, f"{ref}:{ref}", cwd=root)
    except RuntimeError as e:
        say(f"saved locally on {ref}, push to '{remote}' FAILED: {e}")
        return 0
    say(f"backed up {len(files)} file(s) to {remote}/{ref}{' (scrubbed)' if scrub else ' (raw)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
