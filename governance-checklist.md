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

| Done | When | Severity | Found in | Code | Issue | Action |
|---|---|---|---|---|---|---|
| [ ] | 2026-11-04 00:27 | NEEDS REVIEW | File: README.md | D-3 | Mentions confidential / secret / top-secret material | Check the data class, mask it or use synthetic data, get approval before using it with AI (sheet Data Policy) <!-- key:file:README.md:D-3:Mentions confidential / secret / top-secret material:4241021110 --> |
| [ ] | 2026-11-04 00:27 | NEEDS REVIEW | File: README.md | D-5 | Mentions production or real customer data | Check the data class, mask it or use synthetic data, get approval before using it with AI (sheet Data Policy) <!-- key:file:README.md:D-5:Mentions production or real customer data:511684906 --> |
