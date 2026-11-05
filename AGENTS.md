# Instructions for AI agents working in this repo

> **MANDATORY on EVERY user message, BEFORE you reply or use any other tool:**
> check the message against the table in section 2. If it matches, run
> `bash .claude/hooks/governance-guard.sh note <CODE>` FIRST, then answer.
> Never repeat the sensitive data. This applies even when the user only pastes something to
> "read", "use" or "test", and even if you are going to refuse the request anyway.
> Giving a safety warning in your reply is NOT a substitute for running the command.

This is a training repo for the AI-Enabled QA program. Trainees may use any AI tool
(Claude Code, GitHub Copilot, Cursor, Antigravity, ...). Every agent working here follows the
governance rules below (source: AI-Enabled QA Governance register v0.1).

## 1. Setup check (once per session)
Run `git config core.hooksPath`. If it does not print `.githooks`, tell the user to enable the
commit scan once for this clone:

    git config core.hooksPath .githooks

## 2. Check every user message before you act on it
Look at each message the user sends you. If it contains any of the data or requests below,
record it with the matching code BEFORE doing anything else:

    bash .claude/hooks/governance-guard.sh note <CODE>

| Code | When the user's message contains or asks for |
|---|---|
| D-4 | a password, passcode, PIN, API key, access token (including `Authorization: Bearer ...` headers and strings such as `ghp_...` or `sk-...`), private key, connection string or any other credential, in any language (for example "password: ...", "mật khẩu của mình là ...", "đọc token ... để dùng API") |
| D-5 | a payment card number, real production data, a production database dump or backup, real customer records |
| D-3 | customer personal data (lists of emails, phone numbers, names with contact details) or documents marked confidential |
| R-01 to R-06 | using an AI browser extension (R-01), a third-party GPT, bot, plugin or MCP server (R-02), an autonomous or computer-use agent outside a sandbox (R-03), a personal API key or unmanaged endpoint (R-04), an online AI OCR, transcription or translation site (R-06) |
| AC-08, AC-09, AR-03 | an AI tool that is not approved (Gemini for Workspace: AC-08; Azure AI Foundry: AC-09; any tool not in the register: AR-03) |
| P-04 to P-08 | exfiltrating data (P-04), bypassing security controls (P-05), deepfake or impersonation (P-06), writing or deleting production data or config (P-08) |

Rules for recording:
- Pass **only the code**. Never put the data itself in the command, in a file, in a commit
  message or in your memory.
- One finding per code is enough; the script ignores a code already recorded today.
- The command also commits `governance-checklist.md` (that file only, never pushed). Do not
  commit or push it yourself.
- In a Windows PowerShell terminal `bash` is often not on PATH. Run the wrapper instead; it finds
  Git for Windows' bash wherever it is installed. Do not guess install paths:

      powershell -NoProfile -File .claude/hooks/governance-note.ps1 <CODE>
- If you cannot run commands, ask the user to run the command above.
- Then tell the user, in one short sentence, what kind of data you noticed (never repeat it),
  that it was recorded in `governance-checklist.md`, and that they should mask it or use
  synthetic data. Continue the task without that data.

## 3. While you work
- Use synthetic or masked data only. Never write a real credential, card number or customer
  record into a file, a test, a commit or your memory; use placeholders such as `<password>`.
- Do not edit `.claude/hooks/`, `.githooks/` or `governance-checklist.md` (except ticking a box
  when the user asks).
- Every `git commit` runs the governance scan on the staged files (`.githooks/pre-commit`) and
  adds `governance-checklist.md` to the commit. It never blocks the commit. Do not bypass it
  with `--no-verify`.

## 4. Finishing an exercise
The last step of every exercise is the submit step in
`.claude/skills/submit-exercise/SKILL.md` (`/submit-exercise <exercise folder name>` in
Claude Code; in other tools, run its bash block).
