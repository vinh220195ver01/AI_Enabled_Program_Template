#!/usr/bin/env bash
# Stop hook, runs after governance-guard.sh: commit governance-checklist.md. Never pushes.
# The commit is limited to that one file, so exercise work the trainee has staged is
# never swept into it. The checklist commit reaches the remote with the trainee's own push.
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FILE="governance-checklist.md"
cat > /dev/null
cd "$ROOT" || exit 0
[ -f "$FILE" ] || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0
[ -n "$(git branch --show-current)" ] || exit 0
[ -n "$(git status --porcelain -- "$FILE")" ] || exit 0

git add -- "$FILE" > /dev/null 2>&1
# stdout is reserved for governance-guard.sh's JSON (same hook command), so report on stderr
if git commit -q -m "governance: record violations in checklist" -- "$FILE" > /dev/null 2>&1; then
  echo "GOVERNANCE: $FILE committed (not pushed)" >&2
else
  echo "GOVERNANCE: could not commit $FILE" >&2
fi
exit 0
