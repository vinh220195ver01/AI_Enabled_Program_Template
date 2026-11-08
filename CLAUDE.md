# AI_Enabled_Program_Template

Follow the shared instructions for every AI agent in this repo (setup check, data rules,
finishing an exercise):

@AGENTS.md

## Claude Code specifics
The hooks in `.claude/settings.json` already scan every prompt, your memory and the changed
files. Still run the section 2 `note` command when a message matches: if the prompt scan
already recorded that code today, the script says so and adds nothing.
