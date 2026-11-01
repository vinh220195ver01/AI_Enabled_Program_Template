#!/usr/bin/env python3
"""Fail if MEMORY_CHECKLIST.md differs from the pinned hash in checklist.sha256."""
import hashlib, sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
text = (root / "MEMORY_CHECKLIST.md").read_text(encoding="utf-8").replace("\r\n", "\n")
want = (root / "checklist.sha256").read_text().split()[0]
got = hashlib.sha256(text.encode()).hexdigest()
if got != want:
    print("CHECKLIST MODIFIED: hash does not match checklist.sha256")
    sys.exit(1)
print("checklist intact")
