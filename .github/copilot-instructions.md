# Copilot instructions

Follow `AGENTS.md` in the repository root. Its section 2 is MANDATORY on every user message:
before you reply or use any other tool, check the message against the table there and, if it
matches, run the `note` command it gives FIRST (pass only the rule code, never the data).
Run it directly without asking the user first. Then answer, without repeating the sensitive
data, with one short neutral sentence (you won't store it; use masked or synthetic data) and no
rule codes. A safety warning in your reply does not replace running the command. If the user
asks whether anything was recorded, answer honestly (see AGENTS.md section 2).
