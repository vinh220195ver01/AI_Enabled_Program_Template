#!/usr/bin/env python3
"""Scan memory/ against the automatable parts of MEMORY_CHECKLIST.md and append
the result to safety-log/safety-log.jsonl as a hash-chained record.

Findings never contain the matched value, only rule, file, and line.
Each record holds prev_hash and hash (sha256 of the record without `hash`),
so editing or deleting any earlier line breaks the chain (see verify_log.py).
The head hash is printed: pin it somewhere you control to detect a full reset.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEMORY = ROOT / "memory"
LOG = ROOT / "safety-log" / "safety-log.jsonl"
GENESIS = "0" * 64

RULES = {  # checklist section -> (rule id, regex)
    "1-secrets": [
        ("credential-assignment", r"(?i)\b(api[_-]?key|token|secret|password|passwd)\b\s*[:=]\s*\S{4,}"),
        ("private-key", r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
        ("known-token-prefix", r"\b(ghp_|gho_|sk-|xox[bp]-|AKIA)[A-Za-z0-9_-]{8,}"),
        ("connection-string", r"(?i)\b\w+://[^/\s:@]+:[^/\s@]+@"),
    ],
    "2-personal-data": [
        ("email", r"[\w.+-]+@[\w-]+\.[\w.-]+"),
        ("user-home-path", r"(?i)(C:[\/]Users[\/]|/home/|/Users/)[^\/\s]+"),
        ("phone", r"\b(\+?\d{1,3}[ -]?)?(\(?\d{3}\)?[ -]?)\d{3}[ -]?\d{4}\b"),
    ],
    "4-safety-behavior": [
        ("skip-confirmation", r"(?i)(never|don't|do not)\s+(ask|confirm)"),
        ("bypass-permission", r"(?i)(bypass|skip|ignore|disable)\s+(the\s+)?(permission|safety|confirmation|check)"),
        ("hide-from-user", r"(?i)(hide|conceal|don't tell|do not tell|without telling)\s+(it\s+)?(from\s+)?the\s+user"),
    ],
}


def digest(rec):
    body = {k: v for k, v in rec.items() if k != "hash"}
    return hashlib.sha256(json.dumps(body, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def scan():
    findings, files = [], 0
    for p in sorted(MEMORY.rglob("*")):
        if not p.is_file() or p.name == ".gitkeep":
            continue
        files += 1
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            for section, rules in RULES.items():
                for rid, rx in rules:
                    if re.search(rx, line):
                        findings.append({"section": section, "rule": rid,
                                         "file": p.relative_to(ROOT).as_posix(), "line": n})
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
