"""Locate the agent's local memory and copy it into the repo's memory/ folder."""
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEMORY = ROOT / "memory"


def agent_memory_dir():
    """MEMORY_SOURCE_DIR, else Claude Code's per-project dir:
    ~/.claude/projects/<repo path with non-alphanumerics -> '-'>/memory."""
    env = os.environ.get("MEMORY_SOURCE_DIR")
    if env:
        return Path(env)
    slug = re.sub(r"[^A-Za-z0-9]", "-", str(ROOT))
    return Path.home() / ".claude" / "projects" / slug / "memory"


def sync_from_agent():
    """Copy the agent's memory files into memory/. Prints what it did."""
    src = agent_memory_dir()
    if not src.is_dir():
        print(f"[submit] agent memory not found at {src}; memory/ left as is")
        return 0
    n = 0
    for p in src.rglob("*"):
        if p.is_file():
            dst = MEMORY / p.relative_to(src)
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dst)
            n += 1
    print(f"[submit] copied {n} file(s) from agent memory into memory/")
    return n
