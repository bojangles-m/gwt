# gwt — git worktree toolkit

A fast, hackable **zsh** toolkit for git worktrees. Create, switch, open, list, and clean up worktrees with short commands and an fzf picker — without leaving your shell.

```
gwa                     add / create a worktree
gws                     switch to a worktree (cd)
gwo                     open a worktree in your editor
gwr                     remove a worktree
gwl                     status dashboard
gwclean                 remove stale worktrees
gwt doctor              check your setup
gwt update | uninstall
```

## Install

```sh
npx @bojangles/gwt
```

Then restart your shell (or `source ~/.zshrc`) and verify:

```sh
exec zsh          # start a fresh zsh session — or just open a new terminal (zsh is macOS's default)
gwt doctor
```

That's it — no sudo, nothing system-wide. **gwt** is a _sourced zsh plugin_, so the installer copies it to `~/.gwt/gwt.zsh` and adds a single `source` line to your `~/.zshrc`.

## Prerequisites

**Required**

- **git** ≥ 2.7
- **zsh**

**Optional** (each just enables one feature — `gwt doctor` tells you what's missing)

- **fzf** — interactive pickers (without it, pass branch names explicitly)
- an **editor** command for `gwo` / `gwa -o` (see `GWT_OPEN_CMD`)
- **pbcopy** — `gwa -c` clipboard copy (macOS)
- **zsh completion** (`compinit`) — Tab completion

**Install-time only:** **Node** (the `npx` installer uses it). Node is _not_ a runtime dependency and is _not_ checked by `gwt doctor`.

## Quick start

```sh
cd ~/projects/my-app
gwa feature-123          # create a worktree for a new branch off HEAD
gwa -m feature-124       # ...or base the new branch on your local default branch
gwa                      # no name → fzf: adopt an existing branch, or type a new one
gws                      # fzf-switch between worktrees (gws main jumps to the primary)
gwl                      # dashboard: branch · dirty · ahead/behind · last commit
gwr feature-123          # remove the worktree (keep the branch; -d also deletes it)
gwclean                  # remove stale (merged / gone-upstream) worktrees
```

## Commands

| Command                                        | What it does                                                                                                                                                                           |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `gwa [-c\|-o] [-m] [<branch>] [<start-point>]` | Create a worktree. No branch → fzf picker (adopt existing, or type a new name). `-c` copy open-cmd (default), `-o` open in editor, `-m` base a new branch on the local default branch. |
| `gwo [<branch>]`                               | Open a worktree in your editor. No branch → picker (else most recent).                                                                                                                 |
| `gws [-o] [<branch>]`                          | Switch to a worktree (`cd`). No branch → picker. `-o` also opens it.                                                                                                                   |
| `gwr [-d\|-D] [<branch>] [--force]`            | Remove a worktree. Branch kept unless `-d` (safe) / `-D` (force). No branch → multi-picker.                                                                                            |
| `gwl [-a] [-p]`                                | Status dashboard. `-a` every repo under `GWT_WORKTREE_DIR`; `-p` add paths + SHAs.                                                                                                     |
| `gwclean [-n]`                                 | Remove stale worktrees (merged / gone upstream). `-n` dry-run.                                                                                                                         |
| `gwp`                                          | `git worktree prune`.                                                                                                                                                                  |
| `gwt` / `gwt -h`                               | Help (bare = commands, `-h` = + configuration).                                                                                                                                        |
| `gwt -v`                                       | Print the version.                                                                                                                                                                     |
| `gwt doctor`                                   | Setup diagnostics + effective config.                                                                                                                                                  |
| `gwt update`                                   | Update to the latest published version.                                                                                                                                                |
| `gwt uninstall`                                | Remove gwt (asks first).                                                                                                                                                               |

`gwt`, `gwt -h`, `gwt -v`, `gwt doctor`, `gwt update`, and `gwt uninstall` work from anywhere. The worktree commands need to be run inside a git repository.

## Configuration

Set these in your shell (or `~/.zshrc`); `gwt doctor` shows the effective values.

| Variable             | Purpose                                                     | Default                 |
| -------------------- | ----------------------------------------------------------- | ----------------------- |
| `GWT_WORKTREE_DIR`   | Base folder holding all worktrees (`$dir/<repo>/<branch>`)  | `~/dev/workspace`       |
| `GWT_COPY_FILES`     | Gitignored files copied into each new worktree (if present) | `(.env)`                |
| `GWT_OPEN_CMD`       | Command to open a worktree (`{}` = its path)                | `code -n && code -a {}` |
| `GWT_POST_INIT_CMD`  | Command run inside a new worktree after creation            | _(none)_                |
| `GWT_PICKER_OPTIONS` | Extra fzf options for the pickers                           | _(none)_                |

`GWT_COPY_FILES` example for a real project:

```zsh
GWT_COPY_FILES=(.env .npmrc application/config/config-private.php .vscode/launch.json)
```

## Update / uninstall

```sh
gwt update       # upgrade to the latest published version (wraps npx …@latest)
gwt uninstall    # remove the ~/.zshrc line + ~/.gwt (asks first; -y to skip)
```

Manual equivalents if ever needed:
**To updated**: run `npx @bojangles/gwt@latest`
**To uninstall**: delete the `# gwt` block from `~/.zshrc` and `rm -rf ~/.gwt`.

## Development

Work on a clone with edits live on the next shell (no reinstall per change):

```sh
git clone git@github.com:bojangles-m/gwt.git
cd gwt
npm run dev        # or: sh scripts/link.sh  — symlinks ~/.gwt/gwt.zsh → src/gwt.zsh
```

A dev/clone build reports version `0.0.0-dev` (the real version is stamped in only by the `npx` installer).

## Manual / clone install

No npx? Clone and source it directly:

```sh
git clone git@github.com:bojangles-m/gwt.git ~/.gwt-src
echo 'source ~/.gwt-src/src/gwt.zsh' >> ~/.zshrc
```

## Platform

Primary: macOS - the defaults are mac-flavored (`pbcopy`, `code`);

Linux: set `GWT_OPEN_CMD` to your editor and wire your own clipboard.

## License

MIT — see [LICENSE](LICENSE).
