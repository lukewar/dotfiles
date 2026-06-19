#!/usr/bin/env bash
# Re-strips per-project mcpServers from ~/.claude.json (where leaked
# bearer tokens regularly land). Idempotent. Safe to run repeatedly.
#
# Triggered by chezmoi when this file's contents change.
# To force re-run: `chezmoi state delete-bucket --bucket=scriptState`.
set -euo pipefail

CLAUDE="${HOME}/.claude.json"
[[ -f "$CLAUDE" ]] || { echo "no ~/.claude.json — skipping"; exit 0; }

python3 - <<'PY'
import json, sys, pathlib
p = pathlib.Path.home() / ".claude.json"
d = json.loads(p.read_text())
removed = 0
for proj in d.get("projects", {}).values():
    if "mcpServers" in proj:
        del proj["mcpServers"]
        removed += 1
if removed:
    p.write_text(json.dumps(d, indent=2))
    print(f"stripped mcpServers from {removed} project(s) in ~/.claude.json")
else:
    print("no per-project mcpServers found — nothing to do")
PY
