#!/usr/bin/env bash
# AI-Enabled QA governance guard. Needs only bash + grep + git.
#   governance-guard.sh input   UserPromptSubmit hook: scan the trainee's prompt
#   governance-guard.sh stop    Stop hook: scan the agent's local memory AND the repo files
#                               that are changed, untracked or in unpushed commits
#                               ("memory" is accepted as an alias of "stop")
# It never blocks. Every new finding is appended to governance-checklist.md as an open
# checkbox for the owner to review. Only the rule ID, the source and the file path are
# written: the matched text is never copied, so a secret is not written into a repo that
# gets pushed.
# Dedupe: input findings are recorded once per rule per day; memory/file findings once per
# file, rule and matched content (a different secret in the same file is recorded again).
# Input scan: only the "prompt" field of the hook JSON is scanned, not the metadata
# (session id, transcript path, ...) that Claude Code sends with it.
# Repo scan skips: .claude/hooks/ (the rules themselves), memory/ (scanned at its source),
# governance-checklist.md, .git/, and binary files.
# Rule level BLOCK-LUHN = BLOCK, but a match only counts if it passes the Luhn check.
MODE="${1:-input}"
[ "$MODE" = memory ] && MODE=stop
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RULES="$HERE/governance-rules.txt"
CHECKLIST="$ROOT/governance-checklist.md"
INPUT="$(cat)"
TODAY="$(date '+%Y-%m-%d')"

# text to scan in input mode: everything after the "prompt" key (falls back to the whole input)
PROMPT="$INPUT"
case "$INPUT" in *'"prompt"'*) PROMPT="${INPUT#*\"prompt\"}" ;; esac

# one combined regex of every rule: a single grep tells whether anything can match at all,
# so the common case (no findings) skips the per-rule work, which is slow on Windows
COMBINED=""
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  rx="${line#*~~}"; rx="${rx#*~~}"; rx="${rx#*~~}"
  COMBINED="${COMBINED:+$COMBINED|}($rx)"
done < "$RULES"

SRC=""
if [ "$MODE" = stop ]; then
  SLUG="$( (cd "$ROOT" && (pwd -W 2>/dev/null || pwd)) | sed 's/[^A-Za-z0-9]/-/g')"
  SRC="${MEMORY_SOURCE_DIR:-$HOME/.claude/projects/$SLUG/memory}"
  [ -d "$SRC" ] || SRC=""
fi

json_escape() {
  local s
  s="$(printf '%b' "$1")"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

# luhn_ok <digits with optional spaces/dashes>: true for 13-19 digits that pass the Luhn check
luhn_ok() {
  local d="${1//[^0-9]/}" sum=0 alt=0 i n
  [ "${#d}" -ge 13 ] && [ "${#d}" -le 19 ] || return 1
  for ((i=${#d}-1; i>=0; i--)); do
    n="${d:i:1}"
    if [ "$alt" = 1 ]; then n=$((n*2)); [ "$n" -gt 9 ] && n=$((n-9)); fi
    sum=$((sum+n)); alt=$((1-alt))
  done
  [ $((sum%10)) -eq 0 ]
}
# any_luhn: reads candidate matches on stdin, true if at least one passes the Luhn check
any_luhn() {
  local m
  while IFS= read -r m; do luhn_ok "$m" && return 0; done
  return 1
}

init_checklist() {
  [ -f "$CHECKLIST" ] && return
  cat > "$CHECKLIST" <<'HDR'
# Governance checklist

Violations found by the governance guard (rules: AI-Enabled QA Governance register v0.1).
Tick a box when the owner has reviewed it. Only rule IDs and file names are recorded,
never the matched text.

- VIOLATION: sensitive data (secret, key, credential, card number) was used or stored.
  Escalate to Security/Privacy/Data Owner (AR-06).
- NEEDS REVIEW: restricted or unlisted tool, confidential/production data, or risky
  behavior. Not an automatic fail (AR-03, AR-05, AR-07); prohibited behavior (P-*) fails
  only with reliable evidence (AR-04).

HDR
}

# record <source> <rule-id> <level> <message> <dedupe-key>   (returns 1 if already recorded)
record() {
  local source="$1" id="$2" level="$3" msg="$4" key="$5" decision
  if [ -f "$CHECKLIST" ] && grep -Fq "key:$key" "$CHECKLIST"; then return 1; fi
  if [ "$level" = BLOCK ]; then decision="VIOLATION, escalate (AR-06)"
  else
    case "$id" in
      P-*) decision="NEEDS REVIEW, fail only with reliable evidence (AR-04)" ;;
      *)   decision="NEEDS REVIEW (AR-03/05/07)" ;;
    esac
  fi
  init_checklist
  printf -- '- [ ] %s | %s | %s | %s | %s | key:%s\n' "$(date '+%Y-%m-%d %H:%M')" "$source" "$id" "$decision" "$msg" "$key" >> "$CHECKLIST"
}

# repo files worth scanning (relative paths): changed vs HEAD, untracked, and in unpushed commits
REPO_FILES=()
collect_repo_files() {
  git -C "$ROOT" rev-parse --git-dir > /dev/null 2>&1 || return
  local f
  while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$ROOT/$f" ] && REPO_FILES+=("$f")
  done < <( { git -C "$ROOT" -c core.quotepath=off diff --name-only HEAD 2>/dev/null
              git -C "$ROOT" -c core.quotepath=off ls-files -o --exclude-standard 2>/dev/null
              git -C "$ROOT" -c core.quotepath=off log --name-only --format= HEAD --not --remotes=origin 2>/dev/null
            } | sort -u | grep -vE '^(\.claude/hooks/|memory/|\.git/|governance-checklist\.md$)' )
}

recorded=""; sensitive=""

# scan_stop <kind: memory|file> <base dir>: apply every rule to the files of that source
scan_stop() {
  local kind="$1" base="$2" line level rest id msg regex luhn files f sig
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    level="${line%%~~*}"; rest="${line#*~~}"
    id="${rest%%~~*}";    rest="${rest#*~~}"
    msg="${rest%%~~*}";   regex="${rest#*~~}"
    luhn=""; [ "$level" = BLOCK-LUHN ] && { luhn=1; level=BLOCK; }
    if [ "$kind" = memory ]; then
      files="$(cd "$base" && grep -rEIil -e "$regex" . 2>/dev/null | sed 's#^\./##' | sort -u)"
    else
      files="$(cd "$base" && grep -EIil -e "$regex" -- "${REPO_FILES[@]}" 2>/dev/null | sort -u)"
    fi
    [ -n "$files" ] || continue
    while IFS= read -r f; do
      if [ -n "$luhn" ] && ! grep -Eio -e "$regex" "$base/$f" 2>/dev/null | any_luhn; then continue; fi
      sig="$(grep -Ei -e "$regex" "$base/$f" 2>/dev/null | cksum | cut -d' ' -f1)"
      if record "$kind:$f" "$id" "$level" "$msg" "$kind:$f:$id:$msg:$sig"; then
        recorded="$recorded- $id $msg ($kind: $f)\n"
      fi
    done <<< "$files"
  done < "$RULES"
}

if [ "$MODE" = stop ]; then
  if [ -n "$SRC" ] && grep -rEIiq -e "$COMBINED" "$SRC" 2>/dev/null; then scan_stop memory "$SRC"; fi
  collect_repo_files
  if [ "${#REPO_FILES[@]}" -gt 0 ] && (cd "$ROOT" && grep -EIiq -e "$COMBINED" -- "${REPO_FILES[@]}") 2>/dev/null; then
    scan_stop file "$ROOT"
  fi
else
  printf '%s' "$PROMPT" | grep -Eiq -e "$COMBINED" || exit 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    level="${line%%~~*}"; rest="${line#*~~}"
    id="${rest%%~~*}";    rest="${rest#*~~}"
    msg="${rest%%~~*}";   regex="${rest#*~~}"
    luhn=""; [ "$level" = BLOCK-LUHN ] && { luhn=1; level=BLOCK; }
    if [ -n "$luhn" ]; then
      printf '%s' "$PROMPT" | grep -Eio -e "$regex" | any_luhn || continue
    else
      printf '%s' "$PROMPT" | grep -Eiq -e "$regex" || continue
    fi
    [ "$level" = BLOCK ] && sensitive=1
    if record "input" "$id" "$level" "$msg" "input:$TODAY:$id:$msg"; then
      recorded="$recorded- $id $msg\n"
    fi
  done < "$RULES"
fi

if [ "$MODE" = input ]; then
  [ -n "$recorded$sensitive" ] || exit 0
  # the reminder is sent every time sensitive data is seen, even when the entry was already recorded today
  ctx=""; [ -n "$recorded" ] && ctx="GOVERNANCE: recorded in governance-checklist.md:\n$recorded"
  [ -n "$sensitive" ] && ctx="${ctx}The trainee message may contain sensitive data. Do not repeat it and do not save it to memory."
  out="\"hookSpecificOutput\":{\"hookEventName\":\"UserPromptSubmit\",\"additionalContext\":\"$(json_escape "$ctx")\"}"
  [ -n "$recorded" ] && out="\"systemMessage\":\"$(json_escape "GOVERNANCE: recorded in governance-checklist.md:\n$recorded")\",$out"
  printf '{%s}\n' "$out"
else
  [ -n "$recorded" ] || exit 0
  printf '{"systemMessage":"%s"}\n' "$(json_escape "GOVERNANCE: recorded in governance-checklist.md:\n$recorded")"
fi
exit 0
