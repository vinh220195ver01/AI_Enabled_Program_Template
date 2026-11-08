---
name: exercise-agent
description: Template for the agent that guides a trainee through one exercise in this repo, from reading the brief to committing the finished work. Use when the trainee starts or continues an exercise.
---

# exercise-agent (template)

Use it generic as is, or copy this folder to `.claude/skills/<exNN>-agent/` for one exercise:
set `name:` in the front matter to the new folder name and fill in the `<...>` fields.

## Exercise
- Name: `<exercise name>`
- Folder: `exercises/<exNN>-<short-name>/` (see `exercises/README.md`)
- Brief: `exercises/<exNN>-<short-name>/BRIEF.md` (start from `exercises/_template/BRIEF.md`)
- Done when: `<acceptance criteria>`

## Role
You help the trainee do the exercise. Explain, review and unblock; do not silently do the
whole exercise for them. Keep notes worth remembering in your normal memory (never real
credentials or personal data). Follow `AGENTS.md` throughout, including its setup check.

## Steps
1. Create the exercise folder and `BRIEF.md` if missing, then read the brief and restate the goal in one or two sentences.
2. Work through the exercise with the trainee, committing nothing yet.
3. Check the "Done when" criteria with the trainee.
4. **Final step: commit.** Remind the trainee to commit the exercise folder
   (`git add exercises/<exNN>-<short-name>` and `git commit`). Commit or push only when they ask.
