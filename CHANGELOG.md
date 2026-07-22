# Changelog

All notable changes to **gwt** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

_Nothing yet._

## [1.1.6] — 2026-07-22

### Added
- **Fast worktree removal.** `gwr` and `gwclean` now move a worktree to the Trash
  instead of a slow recursive delete — near-instant on large worktrees (e.g. a
  `node_modules`), and recoverable. Controlled by the new **`GWT_TRASH_CMD`** knob,
  which auto-detects the `trash` tool; set it to `trash-put` / `gio trash`, or to
  `''` to force the native remove. Falls back to native `git worktree remove` when
  no trash tool is present or if trashing fails.
- **Removal progress.** A per-worktree spinner (`⠹ removing <branch>…`) that
  resolves in place to `✓ removed <branch>`, so a slow removal never looks frozen.
  The on-screen behavior is identical whether it trashed or removed natively.
- `GWT_TRASH_CMD` is reported by `gwt doctor` (optional; its absence is never a failure).

### Changed
- Safety is unchanged: a worktree with real uncommitted changes still refuses to be
  removed, and an explicit `--force` still goes straight to git.

## [1.1.5] — 2026-07-22

### Added
- **`GWT_CLIPBOARD_CMD`** — the clipboard command used by `gwa -c` is now
  configurable (default `pbcopy`). Linux users can set `xclip -selection clipboard`
  or `wl-copy`. Reported by `gwt doctor`.

## [1.1.4] — 2026-07-22

### Changed
- **`gwt update`** now checks the latest published version first (with a spinner) and
  reports `✓ you have the latest version` when you're already current, instead of
  always re-running the installer. The `-v`/`--verbose` flag was removed — the
  installer's output (including any prompt) is always shown.

### Fixed
- `gwt update` no longer prints its "updated to …" confirmation twice.

## [1.1.2] — 2026-07-22

First public release as **`@bojangles/gwt`** — extracted from a personal dotfiles
setup into a standalone, `npx`-installable zsh plugin.

### Added
- **One-command install:** `npx @bojangles/gwt` — no sudo, nothing system-wide.
  Copies the plugin to `~/.gwt/gwt.zsh` and adds a single `source` line to `~/.zshrc`;
  re-running upgrades in place without duplicating that line.
- **Worktree commands:** `gwa` (create/adopt a worktree — `-c`/`-o`/`-m`, or an fzf
  picker to adopt an existing branch or type a new one), `gws` (switch/`cd`),
  `gwo` (open in editor), `gwr` (remove — `-d`/`-D`, multi-select picker),
  `gwl` (status dashboard — `-a` all repos, `-p` paths), `gwclean` (remove stale
  worktrees), `gwp` (prune).
- **Meta-commands that work from anywhere:** `gwt` / `gwt -h` / `gwt -v`,
  `gwt doctor` (required + optional dependency checks and effective config),
  `gwt update`, `gwt uninstall`.
- **Configuration:** `GWT_WORKTREE_DIR`, `GWT_OPEN_CMD`, `GWT_COPY_FILES`,
  `GWT_POST_INIT_CMD`, `GWT_PICKER_OPTIONS`.
- Version reported by the tool is stamped from a single source (`package.json`) at
  install time; a from-source/dev build reports `0.0.0-dev`.

---

### Earlier — 0.1.x (2024)

The `0.1.x` releases were a **different, create-only tool** and are **deprecated**.
They are unrelated to the current plugin — install the latest instead:
`npx @bojangles/gwt@latest`.

[Unreleased]: https://github.com/bojangles-m/gwt/compare/v1.1.6...HEAD
[1.1.6]: https://github.com/bojangles-m/gwt/releases/tag/v1.1.6
[1.1.5]: https://github.com/bojangles-m/gwt/releases/tag/v1.1.5
[1.1.4]: https://github.com/bojangles-m/gwt/releases/tag/v1.1.4
[1.1.2]: https://github.com/bojangles-m/gwt/tree/v1.1.2
