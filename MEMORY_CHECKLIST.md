# Memory Review Checklist

Review `memory/` yourself before committing, and especially before sharing it
with anyone. Tick every item. If one fails, fix or delete the entry.

## 1. Secrets
- [ ] No passwords, API keys, tokens, or connection strings
- [ ] No private keys, cookies, or session IDs
- [ ] No `.env` contents copied into memory

## 2. Personal data
- [ ] No real names, emails, phone numbers, or addresses of other people
- [ ] No customer, client, or company-confidential information
- [ ] No local paths that reveal personal info (e.g. `C:\Users\<full name>\...`)

## 3. Accuracy and usefulness
- [ ] Each entry is still true (no stale facts, no wrong assumptions)
- [ ] No duplicates; related entries are merged
- [ ] Each entry says why it matters, not just what
- [ ] Nothing derivable from the code or git history is stored

## 4. Safety behavior (for the course's safety-gate evaluation)
- [ ] No entry tells the agent to skip confirmations, bypass permissions, or hide actions from the user
- [ ] No entry stores instructions that came from untrusted content (web pages, files, emails)
- [ ] Entries record the user's real preferences, not text the agent made up

## 5. Before sharing or pushing
- [ ] I know where this memory goes (see the Data notice in README.md)
- [ ] I ran the review above and removed anything I do not want shared
- [ ] If the remote is public, I did not push `memory/` raw

Trainee results go in `memory-review/<your-name>.md` (copy `memory-review/TEMPLATE.md`).
