---
name: submit-exercise
description: Final step of every exercise. Copies the agent's local memory into memory/ and commits it on the current branch together with the staged exercise work. Trainee-invoked only.
disable-model-invocation: true
---

# submit-exercise

Run as `/submit-exercise <exercise name>` when the exercise is finished.
Needs only `git` and a POSIX shell (Git Bash on Windows, which comes with Git). No Python.

## What it does (tell the trainee before running)
1. Replaces `memory/` with a copy of the agent's local memory: `$MEMORY_SOURCE_DIR` if set, else
   `~/.claude/projects/<repo path with every non-alphanumeric char as '-'>/memory`
   (e.g. `C:\AI_Enabled_Program_Template` -> `C--AI-Enabled-Program-Template`).
   Files deleted from the agent's memory are deleted from `memory/` too.
2. Stages `memory/` and commits it on the **current branch**, together with anything
   already staged, with message `submit: <exercise name> + agent memory`.
3. Shows every file in the commit. The memory is raw and unfiltered, so the trainee
   should review it first (see `MEMORY_CHECKLIST.md`).

## Steps for the agent
1. Make sure the exercise work is staged (`git add` the exercise files) and show the trainee
   `git status`.
2. Remind the trainee that raw memory will be committed; wait for a yes.
3. Run this in a POSIX shell from the repo root, replacing `<exercise name>`, and show the
   output as is:
   ```bash
   NAME="<exercise name>"
   ROOT="$(git rev-parse --show-toplevel)"
   SLUG="$(cd "$ROOT" && (pwd -W 2>/dev/null || pwd) | sed 's/[^A-Za-z0-9]/-/g')"
   SRC="${MEMORY_SOURCE_DIR:-$HOME/.claude/projects/$SLUG/memory}"
   echo "[submit] agent memory source: $SRC"
   if [ -d "$SRC" ]; then
     find "$ROOT/memory" -mindepth 1 ! -name .gitkeep -exec rm -rf {} + 2>/dev/null
     cp -R "$SRC"/. "$ROOT/memory/"
     echo "[submit] copied $(find "$SRC" -type f | wc -l) file(s) into memory/"
   else
     echo "[submit] agent memory not found at $SRC; memory/ left as is"
   fi
   git -C "$ROOT" add -A -- memory
   if git -C "$ROOT" diff --cached --quiet; then
     echo "[submit] nothing to commit"
   else
     echo "[submit] files in this commit:"; git -C "$ROOT" diff --cached --name-status
     git -C "$ROOT" commit -q -m "submit: $NAME + agent memory" \
       && echo "[submit] committed on branch '$(git -C "$ROOT" branch --show-current)'"
   fi
   ```
   If the source path printed is wrong, ask the trainee for the right folder and rerun
   with `MEMORY_SOURCE_DIR` set.
4. Ask whether to push. Only on a yes, run `git push -u origin HEAD` and show the output.
Never run this on your own initiative and never hide its output.
