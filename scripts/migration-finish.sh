#!/usr/bin/env bash
# Final migration steps to run ON THE NEW MAC after `chezmoi apply` completes
# and the AI state tarball is extracted.
#
# Usage:  scripts/migration-finish.sh [old-mac-hostname-or-ip]
#
# If you don't pass a hostname, the rsync sections will be skipped (clone-only mode).

set -euo pipefail

OLD_MAC="${1:-}"
HOST_REPO_PREFIX="github"   # default GitHub org for cloning

# ─── 1. Re-clone active workspace repos ─────────────────────────────────────
mkdir -p ~/workspace
cd ~/workspace

REPOS=(
    "github/agentic-automations"
    "github/info-recall-agent"          # was 'clippy' locally
    "github/entitlements"
    "github/hubbers-mcp-server"
    "github/workspace-lukewar:em"
    "github/dependants-sync-action"
    "github/cybercats"
    "github/github-mcp-server"
    "microsoft/markitdown"
    "github/pyhubbers"
    "github/vpn"
)
# NOTE: private personal repos under lukewar/* are intentionally NOT cloned here.
# They live only on the old Mac (or are pushed to GitHub as WIP branches).

for entry in "${REPOS[@]}"; do
    repo="${entry%%:*}"
    name="${entry##*:}"
    [[ "$name" == "$entry" ]] && name=$(basename "$repo")
    if [[ -d "$name/.git" ]]; then
        echo "↻ $name exists — pulling"
        (cd "$name" && git pull --ff-only 2>&1 | tail -1) || echo "  (pull failed, continuing)"
    else
        echo "⬇ cloning $repo → $name"
        gh repo clone "$repo" "$name" 2>&1 | tail -2 || echo "  (clone failed, continuing)"
    fi
done

# ─── 2. Sync ~/Documents from old Mac (optional) ────────────────────────────
if [[ -n "$OLD_MAC" ]]; then
    echo
    echo "==> rsync ~/Documents/ from $OLD_MAC (may take a while)"
    rsync -avh --progress --exclude='.DS_Store' \
        "${OLD_MAC}:Documents/" ~/Documents/
else
    echo
    echo "↷ skipping document sync (no old-mac hostname provided)"
fi

# ─── 3. Verify ──────────────────────────────────────────────────────────────
echo
echo "==> Verification"
echo "  gh:           $(gh auth status 2>&1 | grep -c 'Logged in') ok"
echo "  ssh github:   $(ssh -T git@github.com 2>&1 | head -1)"
echo "  copilot:      $(copilot --version 2>&1 | head -1)"
echo "  sessions:     $(ls ~/.copilot/session-state 2>/dev/null | wc -l | tr -d ' ') restored"
echo "  brewfile:     $(brew bundle check --file=$(chezmoi source-path)/Brewfile 2>&1 | tail -1)"
echo
echo "✓ Migration finish complete."
