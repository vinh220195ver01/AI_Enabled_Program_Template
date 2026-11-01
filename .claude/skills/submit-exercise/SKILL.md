---
name: submit-exercise
description: Final step of every exercise. Copies the agent's local memory into memory/ and commits it on the current branch together with the staged exercise work. Trainee-invoked only.
disable-model-invocation: true
---

# submit-exercise

Run as `/submit-exercise <exercise name>` when the exercise is finished.

## What it does (tell the trainee before running)
1. Copies the agent's local memory (`MEMORY_SOURCE_DIR`, else
   `~/.claude/projects/<repo path with non-alphanumerics as '-'>/memory`) into `memory/`.
2. Stages `memory/` and commits it on the **current branch**, together with anything
   already staged, with message `submit: <exercise name> + agent memory`.
3. Prints every file in the commit. The memory is raw and unfiltered, so the trainee
   should review `memory/` first (see `MEMORY_CHECKLIST.md`).

## Steps for the agent
1. Make sure the exercise work is staged (`git add` the exercise files) and show the trainee
   `git status`.
2. Remind the trainee that raw memory will be committed; wait for a yes.
3. Run `python scripts/submit_exercise.py "<exercise name>"` and show the output as is.
4. Ask whether to push. Only then run it again with `--push`, or `git push`.
Never run this on your own initiative and never hide its output.
