#!/usr/bin/env bash
# AI-Enabled QA governance guard. Needs only bash + grep.
#   governance-guard.sh input   UserPromptSubmit hook: scan the trainee's prompt
#   governance-guard.sh memory  Stop hook: scan the agent's local memory
# It never blocks. Every new finding is appended to governance-checklist.md as an open
# checkbox for the owner to review. Only the rule ID, the source and (for memory) the
# file path are written: the matched text is never copied, so a secret is not
# written into a repo that gets pushed.
# Dedupe: input findings are recorded once per rule per day; memory findings once per
# file, rule and matched content (a different secret in the same file is recorded again).
MODE="${1:-input}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RULES="$HERE/governance-rules.txt"
CHECKLIST="$ROOT/governance-checklist.md"
INPUT="$(cat)"
TODAY="$(date '+%Y-%m-%d')"

if [ "$MODE" = memory ]; then
  SLUG="$( (cd "$ROOT" && (pwd -W 2>/dev/null || pwd)) | sed 's/[^A-Za-z0-9]/-/g')"
  SRC="${MEMORY_SOURCE_DIR:-$HOME/.claude/projects/$SLUG/memory}"
  [ -d "$SRC" ] || exit 0
fi

json_escape() {
  local s
  s="$(printf '%b' "$1")"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"
  printf '%s' "$s"
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

recorded=""; sensitive=""
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  level="${line%%~~*}"; rest="${line#*~~}"
  id="${rest%%~~*}";    rest="${rest#*~~}"
  msg="${rest%%~~*}";   regex="${rest#*~~}"
  if [ "$MODE" = memory ]; then
    files="$(cd "$SRC" && grep -rEil -e "$regex" . 2>/dev/null | sed 's#^\./##' | sort -u)"
    [ -n "$files" ] || continue
    while IFS= read -r f; do
      sig="$(grep -Ei -e "$regex" "$SRC/$f" 2>/dev/null | cksum | cut -d' ' -f1)"
      if record "memory:$f" "$id" "$level" "$msg" "memory:$f:$id:$msg:$sig"; then
        recorded="$recorded- $id $msg (memory: $f)\n"
      fi
    done <<< "$files"
  else
    printf '%s' "$INPUT" | grep -Eiq -e "$regex" || continue
    [ "$level" = BLOCK ] && sensitive=1
    if record "input" "$id" "$level" "$msg" "input:$TODAY:$id:$msg"; then
      recorded="$recorded- $id $msg\n"
    fi
  fi
done < "$RULES"

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
