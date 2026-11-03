# Governance checklist

Violations found by the governance guard (rules: AI-Enabled QA Governance register v0.1).
Tick a box when the owner has reviewed it. Only rule IDs and file names are recorded,
never the matched text.

- VIOLATION: sensitive data (secret, key, credential, card number) was used or stored.
  Escalate to Security/Privacy/Data Owner (AR-06).
- NEEDS REVIEW: restricted or unlisted tool, confidential/production data, or risky
  behavior. Not an automatic fail (AR-03, AR-05, AR-07); prohibited behavior (P-*) fails
  only with reliable evidence (AR-04).

- [ ] 2026-11-03 23:52 | file:README.md | D-3 | NEEDS REVIEW (AR-03/05/07) | Mentions confidential / secret / top-secret material | key:file:README.md:D-3:Mentions confidential / secret / top-secret material:4241021110
- [ ] 2026-11-03 23:53 | file:README.md | D-5 | NEEDS REVIEW (AR-03/05/07) | Mentions production or real customer data | key:file:README.md:D-5:Mentions production or real customer data:511684906
