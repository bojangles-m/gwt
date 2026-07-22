# Changelog

All notable changes to **gwt** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Jump straight into a new worktree.** `gwa -s` (`--switch`) creates or adopts a worktree and drops you right into it (`cd`), in one step. Plain `gwa` still leaves your shell where it is.

## [1.1.6] — 2026-07-22

### Added
- **Removing worktrees is now near-instant.** `gwr` and `gwclean` move a worktree to the Trash instead of slowly deleting every file — a huge difference on worktrees with a big `node_modules`. Bonus: it's recoverable, so you can restore from the Trash if you change your mind.
- **You can see it working.** A little spinner shows `removing <branch>…` and turns into `✓ removed <branch>` when it's done, so a large removal never looks frozen.
- **Use your own trash tool.** `trash` is picked up automatically if it's installed; set `GWT_TRASH_CMD` to use a different one (e.g. `trash-put`, `gio trash`), or to nothing to keep the plain git removal. `gwt doctor` shows which one is active.

### Changed
- Nothing about safety changed: a worktree with real uncommitted changes is still never removed unless you pass `--force`.

## [1.1.5] — 2026-07-22

### Added
- **Choose your clipboard tool.** The command behind `gwa -c` is now configurable via `GWT_CLIPBOARD_CMD` — `pbcopy` on macOS by default, or set `xclip` / `wl-copy` on Linux. Shown in `gwt doctor`.

## [1.1.4] — 2026-07-22

### Changed
- **`gwt update` got smarter.** It now checks for a newer version first and simply tells you `✓ you have the latest version` when you're already current, instead of reinstalling every time. (The `-v` flag was removed — the installer's own output is always shown now.)

### Fixed
- **`gwt update` no longer reports the update twice** — you get a single `updated to …` confirmation.

## [1.1.2] — 2026-07-22

First public release as **`@bojangles/gwt`** — the git-worktree toolkit, lifted out of a
personal dotfiles setup into a standalone tool anyone can install in one command.

### Added
- **One-command install.** `npx @bojangles/gwt` — no `sudo`, nothing system-wide. Re-run it anytime to upgrade.
- **The worktree commands.** `gwa` (create/adopt), `gws` (switch), `gwo` (open in your editor), `gwr` (remove), `gwl` (status dashboard), `gwclean` (tidy up stale worktrees), and `gwp` (prune). When you don't name a branch, an fzf picker helps you choose one.
- **Helpers that work from anywhere.** `gwt doctor` checks your setup, plus `gwt update`, `gwt uninstall`, and `gwt -h` / `-v`.
- **Sensible, adjustable defaults.** Set where worktrees live, how they open, which files are copied into each new one, and a command to run right after creating one.

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
