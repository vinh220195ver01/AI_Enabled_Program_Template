#!/usr/bin/env bash
# Stop hook, runs after governance-guard.sh: commit and push governance-checklist.md.
# The commit is limited to that one file, so exercise work the trainee has staged is
# never swept into it. A failed push is reported but never breaks the session.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FILE="governance-checklist.md"
cat > /dev/null
cd "$ROOT" || exit 0
[ -f "$FILE" ] || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0
branch="$(git branch --show-current)"
[ -n "$branch" ] || exit 0

# stdout is reserved for governance-guard.sh's JSON (same hook command), so report on stderr
say() { printf '%s\n' "$1" >&2; }

if [ -n "$(git status --porcelain -- "$FILE")" ]; then
  git add -- "$FILE" > /dev/null 2>&1
  if ! git commit -q -m "governance: record violations in checklist" -- "$FILE" > /dev/null 2>&1; then
    say "GOVERNANCE: could not commit governance-checklist.md"; exit 0
  fi
  committed=1
fi

# push when there is something unpushed that this hook committed (or a previous push failed)
git remote get-url origin > /dev/null 2>&1 || exit 0
if [ -n "${committed:-}" ] || ! git diff --quiet "@{u}" -- "$FILE" 2>/dev/null; then
  if git push -q -u origin HEAD > /dev/null 2>&1; then
    say "GOVERNANCE: governance-checklist.md committed and pushed"
  else
    say "GOVERNANCE: governance-checklist.md committed, push failed (run git push later)"
  fi
fi
exit 0
