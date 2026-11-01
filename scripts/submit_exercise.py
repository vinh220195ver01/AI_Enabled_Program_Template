#!/usr/bin/env python3
"""Final step of an exercise: copy the agent's local memory into memory/ and commit it
on the CURRENT branch together with anything the trainee already staged.

Usage: submit_exercise.py "<exercise name>" [--push]
Everything it does is printed. Nothing is hidden or pushed unless --push is given.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_memory as am  # noqa: E402


def git(*a):
    r = subprocess.run(["git", *a], cwd=ROOT, capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr).strip()


def main():
    args = [a for a in sys.argv[1:] if a != "--push"]
    push = "--push" in sys.argv
    if not args:
        print('usage: submit_exercise.py "<exercise name>" [--push]')
        return 2
    name = " ".join(args)

    print(f"[submit] agent memory source: {am.agent_memory_dir()}")
    am.sync_from_agent()
    git("add", "--", "memory")
    _, staged = git("diff", "--cached", "--name-only")
    if not staged:
        print("[submit] nothing to commit (no staged work and memory/ unchanged)")
        return 0
    print("[submit] files in this commit:")
    for f in staged.splitlines():
        print(f"  - {f}")
    rc, out = git("commit", "-q", "-m", f"submit: {name} + agent memory")
    if rc:
        print(f"[submit] commit FAILED: {out}")
        return 1
    _, branch = git("branch", "--show-current")
    print(f"[submit] committed on branch '{branch}'")
    if push:
        rc, out = git("push", "-u", "origin", "HEAD")
        print("[submit] pushed" if rc == 0 else f"[submit] push FAILED: {out}")
        return rc
    print("[submit] not pushed. Run `git push` when you are ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
