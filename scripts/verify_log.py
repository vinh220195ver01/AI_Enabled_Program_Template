#!/usr/bin/env python3
"""Verify the hash chain of safety-log/safety-log.jsonl.
Optional arg: expected head hash (pinned elsewhere) to detect a full reset."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan_memory import GENESIS, LOG, digest  # noqa: E402

lines = LOG.read_text(encoding="utf-8").splitlines() if LOG.exists() else []
prev = GENESIS
for i, line in enumerate(lines, 1):
    rec = json.loads(line)
    if rec["prev_hash"] != prev or rec["hash"] != digest(rec):
        print(f"LOG TAMPERED at record {i}")
        sys.exit(1)
    prev = rec["hash"]
if len(sys.argv) > 1 and sys.argv[1] != prev:
    print("LOG HEAD MISMATCH: log was truncated or reset")
    sys.exit(1)
print(f"log intact: {len(lines)} record(s), head {prev}")
