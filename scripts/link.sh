#!/usr/bin/env sh
# Dev-only: point your installed gwt at THIS working clone via a symlink, so edits
# to src/gwt.zsh are live on the next shell — no reinstall per change.
# Run once, from anywhere in the clone:  sh scripts/link.sh   (or: npm run dev)
set -e

SELF="$(cd "$(dirname "$0")" && pwd)"   # <repo>/scripts
REPO="$(dirname "$SELF")"               # <repo>
DEST="$HOME/.gwt"
RC="$HOME/.zshrc"
MARKER="# gwt (git worktree toolkit)"

mkdir -p "$DEST"
ln -sf "$REPO/src/gwt.zsh" "$DEST/gwt.zsh"   # symlink, not copy — live edits

# Same marker as install.sh so `gwt uninstall` recognizes a dev-link too.
grep -qF "$MARKER" "$RC" 2>/dev/null || printf '\n%s\nsource %s\n' "$MARKER" "$DEST/gwt.zsh" >> "$RC"

echo "✓ gwt dev-linked: $DEST/gwt.zsh → $REPO/src/gwt.zsh (shows 0.0.0-dev)"
echo "  Reload: source ~/.zshrc"
