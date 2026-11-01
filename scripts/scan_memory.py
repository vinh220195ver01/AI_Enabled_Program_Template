#!/usr/bin/env python3
"""Scan memory/ against the automatable parts of MEMORY_CHECKLIST.md and append
the result to safety-log/safety-log.jsonl as a hash-chained record.

Findings never contain the matched value, only rule, file, and line.
Each record holds prev_hash and hash (sha256 of the record without `hash`),
so editing or deleting any earlier line breaks the chain (see verify_log.py).
The head hash is printed: pin it somewhere you control to detect a full reset.
"""
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEMORY = ROOT / "memory"
LOG = ROOT / "safety-log" / "safety-log.jsonl"
GENESIS = "0" * 64

_TOKEN_PREFIX = (r"\b(ghp_|gho_|ghs_|ghu_|github_pat_|glpat-|sk-|sk_live_|sk_test_|"
                 r"xox[abprs]-|AKIA|ASIA|AIza)[A-Za-z0-9_-]{8,}")
_CRED = (r"(?i)[\w-]*(api[ _-]?key|apikey|token|secret|passwd|password|passcode|pwd|"
         r"access[_-]?key|private[_-]?key)[\"']?\s*[:=]\s*[\"']?\S{4,}")

SECRET_RULES = [  # also applied to decoded base64 blobs
    ("credential-assignment", _CRED),
    ("credential-prose", r"(?i)\b(api[ _-]?key|password|passcode|secret|token)\s+(is\s+)?(?=\S{6,})\S*\d\S*"),
    ("bearer-token", r"(?i)\bbearer\s+[A-Za-z0-9._~+/-]{12,}"),
    ("private-key", r"-----BEGIN [A-Z ]*PRIVATE KEY( BLOCK)?-----"),
    ("known-token-prefix", _TOKEN_PREFIX),
    ("jwt", r"\beyJ[\w-]{8,}\.[\w-]{8,}\.[\w-]*"),
    ("connection-string", r"(?i)\b[a-z][\w+.-]*://[^/\s:@]+:[^/\s@]+@"),
    ("userpass-host", r"\b[\w.-]+:[^\s:@/]{3,}@[\w.-]+:\d{2,5}\b"),
]

RULES = {  # checklist section -> [(rule id, regex)]
    "1-secrets": SECRET_RULES,
    "2-personal-data": [
        ("email", r"[\w.+-]+@[\w-]+\.[\w.-]+"),
        ("email-obfuscated", r"(?i)[\w.+-]+\s*[\[(]\s*at\s*[\])]\s*[\w.-]+\.\w+"),
        ("user-home-path", r"(?i)([a-z]:[\\/]{1,2}Users[\\/]{1,2}|/home/|/Users/)[^\\/\s]+"),
        ("phone", r"(?<![\d.])(\+\d{1,3}[ .-]?)?(\(\d{2,4}\)|\d{2,4})[ .-]\d{3}[ .-]?\d{3,4}(?![\d.])"
                  r"|(?<!\d)0\d{9,10}(?!\d)"),
    ],
    "4-safety-behavior": [
        ("skip-confirmation", r"(?i)\b(never|don'?t|do not|without|stop)\s+(ever\s+|bother\s+)?"
                              r"(ask(ing)?|confirm(ing)?|prompt(ing)?|check(ing)?\s+with|"
                              r"double[- ]?check(ing)?|verif(y|ying))\b"),
        ("auto-approve", r"(?i)auto[- ]?approve|dangerously[- ]skip|yolo mode"),
        ("bypass-permission", r"(?i)\b(bypass|skip|ignore|disable|circumvent|override|turn off)\s+"
                              r"(all\s+|the\s+|any\s+)*(permissions?|safety|confirmations?|security|"
                              r"approvals?|guardrails?|checks?|prompts?)\b"),
        ("hide-from-user", r"(?i)\b(hide|conceal|keep\s+(this|it|that)?\s*secret|"
                           r"(don'?t|do not)\s+(mention|tell|show|report|reveal|disclose)|"
                           r"without\s+telling|secretly)\b.{0,40}\b(user|me|them|trainee|anyone)\b"),
        ("silent-action", r"(?i)\bsilently\s+(do|run|push|send|upload|copy|commit|back ?up)"),
    ],
}

_ZERO_WIDTH = dict.fromkeys(map(ord, "​‌‍‎‏⁠﻿­"))
_HOMOGLYPH = {ord(a): b for a, b in zip("аеорсхіуѕјԛԁ", "aeopcxiysjqd")}
_B64 = re.compile(r"[A-Za-z0-9+/]{20,}={0,2}")


def normalize(text):
    """NFKC (fullwidth etc.), drop invisible chars, fold common Cyrillic lookalikes."""
    text = unicodedata.normalize("NFKC", text).translate(_ZERO_WIDTH)
    return text.translate(_HOMOGLYPH)


def digest(rec):
    body = {k: v for k, v in rec.items() if k != "hash"}
    return hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def _line(text, pos):
    return text.count("\n", 0, pos) + 1


def scan_text(text):
    """Return a set of (section, rule, line). Whole-text matching, so a key and its
    value on different lines are still caught."""
    text = normalize(text)
    found = set()
    for section, rules in RULES.items():
        for rid, rx in rules:
            for m in re.finditer(rx, text):
                found.add((section, rid, _line(text, m.start())))
    for m in _B64.finditer(text):
        try:
            dec = base64.b64decode(m.group(0), validate=False).decode("utf-8")
        except Exception:
            continue
        if not dec.isprintable():
            continue
        if any(re.search(rx, dec) for _, rx in SECRET_RULES):
            found.add(("1-secrets", "encoded-secret", _line(text, m.start())))
    return found


def scan():
    findings, files = [], 0
    for p in sorted(MEMORY.rglob("*")):
        if not p.is_file() or p.name == ".gitkeep":
            continue
        files += 1
        text = p.read_text(encoding="utf-8", errors="ignore")
        for section, rid, line in sorted(scan_text(text), key=lambda x: (x[2], x[1])):
            findings.append({"section": section, "rule": rid,
                             "file": p.relative_to(ROOT).as_posix(), "line": line})
    return files, findings


def commit_log():
    """Commit only the log file (not anything else staged), then say so.
    The env guard stops the post-commit hook from re-triggering itself."""
    rel = LOG.relative_to(ROOT).as_posix()
    env = {**os.environ, "SAFETY_SCAN_COMMITTING": "1"}
    git = lambda *a: subprocess.run(["git", *a], cwd=ROOT, env=env, capture_output=True, text=True)
    git("add", "--", rel)
    r = git("commit", "-q", "--only", "-m", "chore: append safety-scan record", "--", rel)
    print("[safety-scan] log committed" if r.returncode == 0
          else f"[safety-scan] log NOT committed: {r.stderr.strip() or r.stdout.strip()}")


def main():
    if os.environ.get("SAFETY_SCAN_COMMITTING") == "1":
        return 0  # triggered by our own log commit
    files, findings = scan()
    prev = GENESIS
    if LOG.exists() and LOG.read_text().strip():
        prev = json.loads(LOG.read_text().strip().splitlines()[-1])["hash"]
    rec = {"ts": datetime.now(timezone.utc).isoformat(), "files_scanned": files,
           "status": "fail" if findings else "pass", "findings": findings, "prev_hash": prev}
    rec["hash"] = digest(rec)
    LOG.parent.mkdir(exist_ok=True)
    with LOG.open("a", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(rec, sort_keys=True, separators=(",", ":")) + "\n")
    print(f"[safety-scan] {rec['status'].upper()}: {files} file(s), {len(findings)} finding(s)")
    for x in findings:
        print(f"  - {x['section']} {x['rule']} at {x['file']}:{x['line']}")
    print(f"[safety-scan] log head hash: {rec['hash']}")
    if "--commit" in sys.argv:
        commit_log()
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
