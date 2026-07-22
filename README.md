# 🌳 gwt — git worktree toolkit

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
- a **clipboard command** for `gwa -c` — `pbcopy` on macOS (the default); on Linux set `GWT_CLIPBOARD_CMD` to `xclip`/`wl-copy`
- **trash** — makes `gwr` / `gwclean` near-instant by moving worktrees to the Trash instead of a slow recursive delete (auto-detected; set `GWT_TRASH_CMD` for a different tool)
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

| Command | What it does |
| --- | --- |
| `gwa [-c\|-o\|-s] [-m] [<branch>] [<start-point>]` | **Create or adopt a worktree.** No `<branch>` → fzf picker: adopt an existing branch, or type a new name to create it.<br>`-c` — copy the "open" command to the clipboard _(default)_<br>`-o` — open it in your editor<br>`-s` — switch into it (`cd`)<br>`-m` — base a new branch on your default branch (not `HEAD`) |
| `gwo [<branch>]` | **Open a worktree** in your editor.<br>No `<branch>` → picker (else the most recent). |
| `gws [-o] [<branch>]` | **Switch to a worktree** (`cd`). No `<branch>` → picker.<br>`-o` — also open it in your editor |
| `gwr [-d\|-D] [<branch>] [--force]` | **Remove a worktree.** The branch is kept by default. No `<branch>` → multi-select picker.<br>`-d` — also delete the branch _(safe: refuses if unmerged)_<br>`-D` — also delete the branch _(force)_<br>`--force` — passed straight through to git |
| `gwl [-a] [-p]` | **Status dashboard** — branch · dirty · ahead/behind · last commit.<br>`-a` — every repo under `GWT_WORKTREE_DIR`<br>`-p` — also show each path + short SHA |
| `gwclean [-n]` | **Remove stale worktrees** (merged, or upstream gone).<br>`-n` — dry-run (preview only) |
| `gwp` | **Prune** git's stale worktree bookkeeping (`git worktree prune`). |
| `gwt` / `gwt -h` | **Help** — bare lists commands; `-h` adds configuration. |
| `gwt -v` | **Version** — prints the bare version string. |
| `gwt doctor` | **Diagnostics** — checks your setup and shows the effective configuration. |
| `gwt update` | **Update** to the latest published version. |
| `gwt uninstall` | **Uninstall** gwt (asks first; `-y` to skip). |

`gwt`, `gwt -h`, `gwt -v`, `gwt doctor`, `gwt update`, and `gwt uninstall` work from anywhere. The worktree commands need to be run inside a git repository.

## Configuration

Set these in your shell (or `~/.zshrc`); `gwt doctor` shows the effective values.

| Variable             | Purpose                                                     | Default                 |
| -------------------- | ----------------------------------------------------------- | ----------------------- |
| `GWT_WORKTREE_DIR`   | Base folder holding all worktrees (`$dir/<repo>/<branch>`)  | `~/dev/workspace`       |
| `GWT_COPY_FILES`     | Gitignored files copied into each new worktree (if present) | `(.env)`                |
| `GWT_OPEN_CMD`       | Command to open a worktree (`{}` = its path)                | `code -n && code -a {}` |
| `GWT_CLIPBOARD_CMD`  | Command reading stdin → clipboard, for `gwa -c`             | `pbcopy` (macOS)        |
| `GWT_POST_INIT_CMD`  | Command run inside a new worktree after creation            | _(none)_                |
| `GWT_PICKER_OPTIONS` | Extra fzf options for the pickers                           | _(none)_                |
| `GWT_TRASH_CMD`      | Command to trash a path → fast `gwr`/`gwclean` (`''`=native) | auto (`trash` if found) |

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

Linux:

- Configure `GWT_OPEN_CMD` with your preferred editor.
- Configure `GWT_CLIPBOARD_CMD` with your preferred clipboard tool (`xclip -selection clipboard` or `wl-copy`).

## License

MIT — see [LICENSE](LICENSE).
