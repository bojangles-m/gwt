#!/usr/bin/env sh
# gwt installer — run via: npx @bojangles/gwt
#
# It copies the plugin into ~/.gwt and adds `source` line to ~/.zshrc. No sudo, nothing system-wide.
set -e

# Resolve this script's real directory, following symlinks — npm exposes the bin
# through a symlink in node_modules/.bin, so $0 is usually that link, not the file.
SELF="$0"
while [ -h "$SELF" ]; do
    dir="$(cd "$(dirname "$SELF")" && pwd)"
    SELF="$(readlink "$SELF")"
    case "$SELF" in /*) ;; *) SELF="$dir/$SELF" ;; esac
done
PKG="$(cd "$(dirname "$SELF")" && pwd)"   # package root (contains src/, package.json)

DEST="$HOME/.gwt"
RC="$HOME/.zshrc"
MARKER="# gwt (git worktree toolkit)"

# Single source of truth for the version is in package.json.
VERSION="$(node -p "require('$PKG/package.json').version")"

mkdir -p "$DEST"
# Drop any stale file/symlink first: a redirection follows a symlink.
rm -f "$DEST/gwt.zsh"
sed 's/GWT_VERSION="0.0.0-dev"/GWT_VERSION="'"$VERSION"'"/' "$PKG/src/gwt.zsh" > "$DEST/gwt.zsh"

# Idempotent wiring: key on the stable marker, never the source line's text, so
# re-running never duplicates the block (and `gwt uninstall` removes it cleanly).
if ! grep -qF "$MARKER" "$RC" 2>/dev/null; then
    printf '\n%s\nsource %s\n' "$MARKER" "$DEST/gwt.zsh" >> "$RC"
fi

echo "✓ gwt $VERSION installed → $DEST/gwt.zsh"
echo "  Restart your shell (or: source ~/.zshrc), then run: gwt doctor"
