#!/usr/bin/env bash
# AI-Enabled QA governance guard. Needs only bash + grep + git.
#   governance-guard.sh input   UserPromptSubmit hook: scan the trainee's prompt
#   governance-guard.sh stop    Stop hook: scan the agent's local memory AND the repo files
#                               that are changed, untracked or in unpushed commits
#                               ("memory" is accepted as an alias of "stop")
#   governance-guard.sh commit  git pre-commit hook (.githooks/pre-commit), works with ANY AI
#                               tool or editor: scan the staged content of the files in the
#                               commit (memory/ included) and add the checklist to the commit
#   governance-guard.sh note <CODE>
#                               for any AI agent (see AGENTS.md): record that the user's
#                               message contained data of rule <CODE> (D-3, D-4, D-5, R-0x,
#                               P-0x, AC-xx, AR-xx). Only the code is passed, never the data.
#                               The checklist is then committed (that file only, never pushed).
# It never blocks. Every new finding is appended to governance-checklist.md as a table row
# for the owner to review. Only the rule code, the source and the file path are written:
# the matched text is never copied, so a secret is not written into a repo that gets pushed.
#
# Dedupe
#   input:        once per rule per day.
#   memory/files: once per file and rule WHILE IT STAYS FLAGGED. Fixing the file ends the
#                 finding; if it is flagged again later, it is recorded again. Editing a
#                 flagged file without fixing it (or reverting the edit) adds nothing.
#   The scan state lives in .git/governance-state (never committed or pushed). Only files
#   that changed since the last run are scanned, which keeps the Stop hook fast.
#   Without that state (first run, fresh clone) a finding already listed in the checklist,
#   in the old list format or the table format, is not recorded twice.
# Input scan: only the "prompt" field of the hook JSON is scanned, not the metadata
# (session id, transcript path, ...) that Claude Code sends with it.
# Repo scan skips: .claude/hooks/ and .claude/skills/ (the rules and skill docs), memory/
# (scanned at its source), the template docs (README.md, CLAUDE.md, exercises/README.md,
# exercises/_template/), governance-checklist.md, .git/, and binary files.
# Rule level BLOCK-LUHN = BLOCK, but a match only counts if it passes the Luhn check.
MODE="${1:-input}"
[ "$MODE" = memory ] && MODE=stop
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RULES="$HERE/governance-rules.txt"
CHECKLIST="$ROOT/governance-checklist.md"
# only the Claude Code hooks get JSON on stdin; never wait on stdin in the other modes
INPUT=""
case "$MODE" in input|stop) INPUT="$(cat)" ;; esac
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
Only rule codes and file names are recorded, never the matched text.
Change `[ ]` to `[x]` when the owner has reviewed a row.

**Severity**
- **VIOLATION**: sensitive data (secret, key, credential, card number) was used or stored.
  Escalate to Security/Privacy/Data Owner (AR-06).
- **NEEDS REVIEW**: restricted or unlisted tool, confidential/production data, or risky
  behavior. Not an automatic fail (AR-03, AR-05, AR-07); prohibited behavior (P-*) fails
  only with reliable evidence (AR-04).

**Rule codes** (look them up in the AI-Enabled QA_Governance Excel file)
- D-3, D-4, D-5: data classification (sheet Data Policy): Confidential, Secret, Top Secret
- R-01 to R-06: restricted tools (sheet Restricted)
- AC-xx: AI tools (sheet AI Tools); AC-08 and AC-09 are Needs Review
- P-04 to P-08: prohibited behavior (sheet Prohibited)
- AR-xx: assessor decision rules (sheet Assessor Rules)

**Found in**: `Prompt` is what the trainee typed; `Agent memory (not in repo)` is a file in the
agent's own memory folder (outside this repo); `File` is a file in this repo.
A row marked "flagged again" means the same file and rule was flagged earlier, then fixed.

HDR
  table_header >> "$CHECKLIST"
}

table_header() {
  printf '%s\n' '| Done | When | Severity | Found in | Code | Issue | Action |' '|---|---|---|---|---|---|---|'
}

# already_listed <memory|file> <path> <rule-id>: is this finding already in the checklist
# (old list format "| memory:x | D-4 |" or table format "| Memory: x | D-4 |")?
already_listed() {
  [ -f "$CHECKLIST" ] || return 1
  local lab="File"; [ "$1" = memory ] && lab="Agent memory (not in repo)"
  grep -Fq -e "| $1:$2 | $3 |" -e "| $lab: $2 | $3 |" -e "| Memory: $2 | $3 |" "$CHECKLIST"
}

# record <source> <rule-id> <level> <message> <dedupe-key or empty>   (returns 1 if already recorded)
record() {
  local source="$1" id="$2" level="$3" msg="$4" key="$5"
  if [ -n "$key" ] && [ -f "$CHECKLIST" ] && grep -Fq "key:$key" "$CHECKLIST"; then return 1; fi
  migrate_checklist
  classify "$level" "$id"
  init_checklist
  # a checklist without a table yet gets one
  grep -q '^| Done ' "$CHECKLIST" || { printf '\n' >> "$CHECKLIST"; table_header >> "$CHECKLIST"; }
  printf -- '| [ ] | %s | %s | %s | %s | %s | %s%s |\n' \
    "$(date '+%Y-%m-%d %H:%M')" "$LABEL" "$(where_for "$source")" "$id" "$msg" "$ACTION" "${key:+ <!-- key:$key -->}" >> "$CHECKLIST"
}

# classify <BLOCK|WARN> <rule-id>: sets LABEL and ACTION for a table row
classify() {
  if [ "$1" = BLOCK ]; then
    LABEL="VIOLATION"
    ACTION="Remove or mask the data at its source; escalate to Security/Privacy/Data Owner (AR-06)"
  else
    LABEL="NEEDS REVIEW"
    case "$2" in
      P-*)       ACTION="Verify what actually happened; a violation only with reliable evidence (AR-04)" ;;
      R-*)       ACTION="Restricted tool: no internal or customer data; get approval first (sheet Restricted)" ;;
      AC-*|AR-*) ACTION="Check sheet AI Tools; an unapproved tool may only handle public or synthetic data (AR-03)" ;;
      *)         ACTION="Check the data class, mask it or use synthetic data, get approval before using it with AI (sheet Data Policy)" ;;
    esac
  fi
}

# where_for <source>: text of the "Found in" column
where_for() {
  local w
  case "$1" in
    input)    w="Prompt" ;;
    agent)    w="Prompt (reported by the agent)" ;;
    memory:*) w="Agent memory (not in repo): ${1#memory:}" ;;
    file:*)   w="File: ${1#file:}" ;;
    *)        w="$1" ;;
  esac
  printf '%s' "${w//|/\\|}"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# migrate_checklist: bring a checklist written by an older version up to date, once:
#  - list rows ("- [ ] when | source | code | decision | issue") become table rows, placed at the
#    top of the table, keeping a ticked [x]
#  - the old "Memory:" label becomes "Agent memory (not in repo):"
#  - dedupe comments of memory/file rows are removed (those rows are not deduped by key any more)
migrate_checklist() {
  [ -f "$CHECKLIST" ] || return 0
  grep -qE '^- \[[ x]\] |\| Memory: |key:(memory|file):' "$CHECKLIST" || return 0
  local line mark when src id decision msg rest level rows="" inserted="" tmp="$CHECKLIST.tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      '- [ ] '*|'- [x] '*)
        mark="${line:3:1}"; line="${line:6}"
        IFS='|' read -r when src id decision msg rest <<< "$line"
        when="$(trim "$when")"; src="$(trim "$src")"; id="$(trim "$id")"; decision="$(trim "$decision")"; msg="$(trim "$msg")"
        level=WARN; case "$decision" in VIOLATION*) level=BLOCK ;; esac
        classify "$level" "$id"
        rows="$rows| [$mark] | $when | $LABEL | $(where_for "$src") | $id | $msg | $ACTION |"$'\n'
        ;;
    esac
  done < "$CHECKLIST"
  : > "$tmp"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in '- [ ] '*|'- [x] '*) continue ;; esac
    printf '%s\n' "$line" >> "$tmp"
    if [ -z "$inserted" ] && [ "${line:0:5}" = '|---|' ]; then printf '%s' "$rows" >> "$tmp"; inserted=1; fi
  done < "$CHECKLIST"
  if [ -z "$inserted" ] && [ -n "$rows" ]; then
    printf '\n' >> "$tmp"; table_header >> "$tmp"; printf '%s' "$rows" >> "$tmp"
  fi
  sed -E 's/ <!-- key:(memory|file):[^>]*-->//; s/\| Memory: /| Agent memory (not in repo): /' "$tmp" > "$CHECKLIST"
  rm -f "$tmp"
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
            } | sort -u | grep -vE '^(\.claude/hooks/|\.claude/skills/|\.githooks/|\.github/copilot-instructions\.md$|memory/|\.git/|governance-checklist\.md$|README\.md$|CLAUDE\.md$|AGENTS\.md$|exercises/README\.md$|exercises/_template/)' )
}

recorded=""; sensitive=""

# note mode: an AI agent reports a finding by rule code only (see AGENTS.md)
if [ "$MODE" = note ]; then
  id="${2:-}"
  case "$id" in
    D-3|D-4|D-5|R-0[1-6]|P-0[1-8]|AC-[0-9][0-9]|AR-0[1-7]) ;;
    *) echo "usage: bash .claude/hooks/governance-guard.sh note <CODE>   (CODE: D-3 D-4 D-5 R-01..R-06 P-01..P-08 AC-xx AR-xx; see AGENTS.md)" >&2; exit 2 ;;
  esac
  case "$id" in D-4|D-5) level=BLOCK ;; *) level=WARN ;; esac
  case "$id" in
    D-3) msg="Reported by the agent: confidential data (customer PII, client documents)" ;;
    D-4) msg="Reported by the agent: secret data (password, token, key, credential)" ;;
    D-5) msg="Reported by the agent: top secret data (card number, production or real customer data)" ;;
    R-*) msg="Reported by the agent: restricted tool used or requested" ;;
    P-*) msg="Reported by the agent: possibly prohibited behavior requested" ;;
    *)   msg="Reported by the agent: AI tool not approved for this data" ;;
  esac
  if record "agent" "$id" "$level" "$msg" "note:$TODAY:$id"; then
    echo "GOVERNANCE: recorded $id in governance-checklist.md"
  else
    echo "GOVERNANCE: $id was already recorded today"
  fi
  # outside Claude Code there is no "agent finished" event, so commit the checklist now
  # (only that file, never pushed), like governance-commit.sh does at the end of a Claude Code turn
  bash "$HERE/governance-commit.sh" < /dev/null
  exit 0
fi
OLD_STATE=""; NEW_ACTIVE=""; BOOTSTRAP=""; SCAN_FILES=()

# scan_stop <kind: memory|file> <base dir>: apply every rule to SCAN_FILES (relative to base)
scan_stop() {
  local kind="$1" base="$2" line level rest id msg regex luhn files f akey note
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in ''|'#'*) continue ;; esac
    level="${line%%~~*}"; rest="${line#*~~}"
    id="${rest%%~~*}";    rest="${rest#*~~}"
    msg="${rest%%~~*}";   regex="${rest#*~~}"
    luhn=""; [ "$level" = BLOCK-LUHN ] && { luhn=1; level=BLOCK; }
    files="$(cd "$base" && grep -EIil -e "$regex" -- "${SCAN_FILES[@]}" 2>/dev/null | sort -u)"
    [ -n "$files" ] || continue
    while IFS= read -r f; do
      if [ -n "$luhn" ] && ! grep -Eio -e "$regex" "$base/$f" 2>/dev/null | any_luhn; then continue; fi
      akey="A|$kind:$f|$id:$msg"
      NEW_ACTIVE="$NEW_ACTIVE$akey"$'\n'
      # still flagged from an earlier run: nothing new
      case $'\n'"$OLD_STATE"$'\n' in *$'\n'"$akey"$'\n'*) continue ;; esac
      # already in the checklist: with no state yet (first run / fresh clone) do not duplicate it;
      # otherwise it was fixed and is flagged again, so record it and say so
      note=""
      if already_listed "$kind" "$f" "$id"; then
        [ -n "$BOOTSTRAP" ] && continue
        note=" (flagged again after an earlier fix)"
      fi
      if record "$kind:$f" "$id" "$level" "$msg$note" ""; then
        recorded="$recorded- $id $msg ($kind: $f)\n"
      fi
    done <<< "$files"
  done < "$RULES"
}

# files of <kind> whose "kind:path|mtime|size" signature is in $CHANGED
changed_files() {
  local kind="$1" l p
  SCAN_FILES=()
  while IFS= read -r l; do
    p="${l%%|*}"
    case "$p" in "$kind:"*) SCAN_FILES+=("${p#"$kind":}") ;; esac
  done <<< "$CHANGED"
}

if [ "$MODE" = stop ]; then
  GITDIR="$(git -C "$ROOT" rev-parse --absolute-git-dir 2>/dev/null)"
  STATE=""; [ -n "$GITDIR" ] && STATE="$GITDIR/governance-state"
  if [ -n "$STATE" ] && [ -f "$STATE" ]; then OLD_STATE="$(cat "$STATE")"; else BOOTSTRAP=1; fi
  OLD_SIGS="$(printf '%s\n' "$OLD_STATE" | sed -n 's/^S|//p')"

  # current signatures (one find / one stat call for all files)
  CUR_SIGS=""
  [ -n "$SRC" ] && CUR_SIGS="$(find "$SRC" -type f -printf 'memory:%P|%T@|%s\n' 2>/dev/null)"
  collect_repo_files
  if [ "${#REPO_FILES[@]}" -gt 0 ]; then
    CUR_SIGS="$CUR_SIGS"$'\n'"$(cd "$ROOT" && stat -c 'file:%n|%Y|%s' -- "${REPO_FILES[@]}" 2>/dev/null)"
  fi
  CUR_SIGS="$(printf '%s\n' "$CUR_SIGS" | grep -v '^$')"

  CHANGED="$(printf '%s\n' "$CUR_SIGS" | grep -vxFf <(printf '%s\n' "$OLD_SIGS"))"
  UNCHANGED="$(printf '%s\n' "$CUR_SIGS" | grep -xFf <(printf '%s\n' "$OLD_SIGS") | grep -v '^$')"

  if [ -n "$SRC" ]; then
    changed_files memory
    if [ "${#SCAN_FILES[@]}" -gt 0 ] && (cd "$SRC" && grep -EIiq -e "$COMBINED" -- "${SCAN_FILES[@]}") 2>/dev/null; then
      scan_stop memory "$SRC"
    fi
  fi
  changed_files file
  if [ "${#SCAN_FILES[@]}" -gt 0 ] && (cd "$ROOT" && grep -EIiq -e "$COMBINED" -- "${SCAN_FILES[@]}") 2>/dev/null; then
    scan_stop file "$ROOT"
  fi

  # save state: all current signatures, plus the flagged findings of unchanged files (carried
  # over) and of the files scanned now
  if [ -n "$STATE" ]; then
    declare -A UNCH=()
    while IFS= read -r l; do [ -n "$l" ] && UNCH["${l%%|*}"]=1; done <<< "$UNCHANGED"
    {
      printf '%s\n' "$CUR_SIGS" | sed 's/^/S|/'
      while IFS= read -r l; do
        case "$l" in A\|*) k="${l#A|}"; k="${k%%|*}"; [ -n "${UNCH[$k]:-}" ] && printf '%s\n' "$l" ;; esac
      done <<< "$OLD_STATE"
      printf '%s' "$NEW_ACTIVE"
    } > "$STATE"
  fi
elif [ "$MODE" = commit ]; then
  # scan what is actually being committed: the staged content, exported to a temp folder
  TMPD="$(mktemp -d 2>/dev/null)" || TMPD="${TMPDIR:-/tmp}/governance.$$"
  mkdir -p "$TMPD"
  SCAN_FILES=()
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    mkdir -p "$TMPD/$(dirname "$f")"
    git -C "$ROOT" show ":$f" > "$TMPD/$f" 2>/dev/null && SCAN_FILES+=("$f")
  done < <(git -C "$ROOT" -c core.quotepath=off diff --cached --name-only --diff-filter=ACMR 2>/dev/null \
           | grep -vE '^(\.claude/hooks/|\.claude/skills/|\.githooks/|\.github/copilot-instructions\.md$|\.git/|governance-checklist\.md$|README\.md$|CLAUDE\.md$|AGENTS\.md$|exercises/README\.md$|exercises/_template/)')
  # a file and rule already listed in the checklist is not recorded again
  BOOTSTRAP=1
  if [ "${#SCAN_FILES[@]}" -gt 0 ] && (cd "$TMPD" && grep -EIiq -e "$COMBINED" -- "${SCAN_FILES[@]}") 2>/dev/null; then
    scan_stop file "$TMPD"
  fi
  rm -rf "$TMPD"
  # the checklist (new rows from this scan, the agent's notes, the prompt hook) goes into this commit
  if [ -f "$CHECKLIST" ] && [ -n "$(git -C "$ROOT" status --porcelain -- governance-checklist.md 2>/dev/null)" ]; then
    git -C "$ROOT" add -- governance-checklist.md > /dev/null 2>&1 && checklist_added=1
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
elif [ "$MODE" = commit ]; then
  # plain text for the terminal / the tool that ran git commit; the commit is never blocked
  [ -n "$recorded" ] && printf '%b' "GOVERNANCE (pre-commit): recorded in governance-checklist.md:\n$recorded" >&2
  [ -n "${checklist_added:-}" ] && echo "GOVERNANCE (pre-commit): governance-checklist.md added to this commit" >&2
  exit 0
else
  [ -n "$recorded" ] || exit 0
  printf '{"systemMessage":"%s"}\n' "$(json_escape "GOVERNANCE: recorded in governance-checklist.md:\n$recorded")"
fi
exit 0
