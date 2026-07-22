# Tech-Spec Inputs — gwt

> **This is raw material for a Technical Specification, NOT the tech spec itself.**
> It captures the HOW-level detail that the PRD (`gwt-prd.md`) deliberately excludes —
> file locations, git plumbing, algorithms, the installer mechanism — so a future
> `to-tech-spec` pass (or a maintainer) has it in one place instead of only in code
> comments. **Status: the tool is implemented and shipped (`@bojangles/gwt`, current 1.1.5);
> this reflects the shipped code.** Items are decided ("locked") unless marked OPEN.

---

## A. Packaging & distribution

### A.1 Repo layout (`@bojangles/gwt`)

Reuses `github.com/bojangles-m/gwt` (kept `.git` history + MIT `LICENSE`).

```
gwt/
├── package.json        # name @bojangles/gwt; "version" = SINGLE source of truth; bin → install.sh
├── src/
│   └── gwt.zsh         # the plugin (ships GWT_VERSION="0.0.0-dev" placeholder)
├── install.sh          # npm `bin` = the npx entrypoint (copy + version-stamp + wire .zshrc)
├── scripts/
│   └── link.sh         # dev-only, repo-only: symlink the installed copy → working clone
├── docs/               # gwt-prd.md + this file (NOT published)
├── README.md
└── LICENSE             # MIT
```

`package.json` shape:
- `name`: `@bojangles/gwt`; `version`: `1.1.5` (current); `license`: `MIT`.
- `bin`: `{ "gwt-install": "install.sh" }` — single bin; `npx @bojangles/gwt` runs the sole bin regardless of name.
- `files`: `["src/gwt.zsh", "install.sh", "README.md", "LICENSE"]` — `scripts/` and `docs/` excluded (dev-only).
- `scripts`: `{ "dev": "sh scripts/link.sh" }` → `npm run dev` (named `dev`, not `link`, to avoid confusion with built-in `npm link`).
- `publishConfig.access`: `public` (scoped package).
- `engines`: none — installer only needs a Node new enough for `node -p`.

### A.2 Install mechanism (`install.sh`)

- Headline install: `npx @bojangles/gwt`. Node is present because it's `npx` → **install-time only**, not a runtime dep, not a doctor check.
- App copy lives at **`~/.gwt/gwt.zsh`**; `~/.zshrc` gets an idempotent block. No `sudo`, no `/usr/local/bin` (sourced plugin, not a PATH binary — a child process can't `cd` the parent shell or define functions/completions).
- **`$0` symlink resolution:** npm exposes the bin via `node_modules/.bin`, so `$0` is usually that symlink. `install.sh` walks the symlink chain to find the real package root (contains `src/`, `package.json`).
- **Version stamp:** `VERSION="$(node -p "require('$PKG/package.json').version")"`, then `sed 's/GWT_VERSION="0.0.0-dev"/GWT_VERSION="'"$VERSION"'"/'` from `src/gwt.zsh` into `~/.gwt/gwt.zsh`.
- **Symlink safety:** `rm -f "$DEST/gwt.zsh"` before the `sed >` — shell redirection follows symlinks, so without it an `npx` re-run over a dev-linked dest would write the published code THROUGH the link into the clone, destroying the `0.0.0-dev` placeholder + uncommitted work.
- **Idempotent wiring:** a stable marker `# gwt (git worktree toolkit)` guards the `.zshrc` block (`grep -qF "$MARKER" || printf '\n%s\nsource %s\n' …`). Keyed on the marker, never the source line's text, so install / `scripts/link.sh` / `gwt uninstall` all agree.
- **First-install vs update messaging:** `WAS_INSTALLED` captured (`[ -e "$DEST/gwt.zsh" ]`) *before* overwrite. Update path prints `✓ gwt updated to <version>` + restart line; first-install path adds the `gwt doctor` next step. **`install.sh` is the sole owner of the "updated to" line** — `gwt update` prints nothing on success, so it appears exactly once (an earlier build double-printed).
- RESOLVED (was OPEN): `GWT_VERSION="0.0.0-dev"` occurs exactly once in `src/gwt.zsh` (the declaration, line 5) → the stamp is unambiguous.

### A.3 Version single-source-of-truth

Truth = `package.json` `"version"`. Repo ships `GWT_VERSION="0.0.0-dev"`; installer stamps the real version into the copied file. No sidecar VERSION file, no runtime file read. Dev/clone copies keep `0.0.0-dev` → clearly a dev build. Release = bump `package.json` only. First public 1.x release was `1.1.2`; current `1.1.5`. The old `0.1.x` create-tool line is superseded (see §D pending).

### A.4 Update (`gwt update` → `_gwt_update`)

Thin wrapper over `npx @bojangles/gwt@latest`. Works anywhere. **No verbose flag** (an earlier `-v`/`--verbose` design was dropped — the npx call is always streamed, so nothing is left to reveal).

1. Reject any argument (`gwt update` takes none).
2. **Dev-link guard:** `[[ -L "$HOME/.gwt/gwt.zsh" ]]` → refuse; direct the user to `git pull` in their clone.
3. **Version pre-check + spinner:** run `npm view @bojangles/gwt version --prefer-online` backgrounded (`setopt local_options no_monitor`, output → `mktemp`) while `_gwt_spin $!` shows a TTY-gated braille spinner. `--prefer-online` so a stale npm cache can't report an old version.
   - Empty result → `couldn't reach npm — check your connection`, non-zero exit.
   - `is-at-least "$latest" "$current"` (installed ≥ latest) → `✓ you have the latest version (<current>)`, exit 0, **no npx run**.
4. Otherwise `npx @bojangles/gwt@latest` **streamed straight through** (never captured) so any interactive install prompt / real error stays visible; non-zero → `update failed — see the npx output above`.
5. No success message of its own (see A.2 — `install.sh` owns it).

### A.5 Uninstall (`gwt uninstall` → `_gwt_uninstall`)

Works anywhere, no repo, no network/Node.
1. Parse `-y`/`--yes` (skip prompt).
2. Print what will be removed (`~/.zshrc` block + `~/.gwt`). **Dev-link case:** if `~/.gwt/gwt.zsh` is a symlink, add a heads-up, then proceed on confirm (warn-then-proceed, NOT refuse — clone stays).
3. Prompt `[y/N]` (default No) via `read "ans?…"` unless `--yes`.
4. Remove the `.zshrc` block with `awk`: match the marker line (`/^# gwt \(git worktree toolkit\)$/ { skip = 2 }`), drop it + the next line (`skip > 0 { skip--; next }`), write through a temp file then copy back (interrupt-safe).
5. `rm -rf "$HOME/.gwt"` (symlink-safe for a dev-link — removes the link, not the clone).
6. Note that commands persist in the current shell until restart.

Fallback (tool won't load): README documents manual removal (delete the `# gwt` block + `rm -rf ~/.gwt`). No `npx … uninstall` (would need Node+network; worse than manual).

### A.6 Dev loop (`scripts/link.sh`)

Symlinks `~/.gwt/gwt.zsh` → the clone's `src/gwt.zsh` (not a copy) and ensures the `.zshrc` marker+source line (same marker as install). Edits are live on next shell; reports `0.0.0-dev`. Resolves the repo root from its own path; run via `sh scripts/link.sh` or `npm run dev`.

---

## B. Command internals & git plumbing

### B.1 Shared helpers

- **`_gwt_require_repo`** — `git rev-parse --is-inside-work-tree`; on failure emits the uniform `not inside a git repository` and returns 1. Called first in `gwa`/`gws`/`gwo`/`gwr`/`gwclean` and in `gwl`'s non-`-a` branch.
- **`_gwt_split_args`** — splits argv into caller-local `flags` (tokens starting `-`) and `pos` arrays.
- **`_gwt_repo_dir`** — `REPLY = $GWT_WORKTREE_DIR/<repo>` where `<repo>` = basename of the parent of `git rev-parse --git-common-dir` (resolved absolute). Errors cleanly outside a repo.
- **`_gwt_wt_path <branch>`** — `REPLY = <repo dir>/${branch//\//-}` (slash-flatten for the folder; branch keeps its real name).
- **`_gwt_worktrees [dir]`** — parses `git worktree list --porcelain` into `reply=("path<TAB>branch" …)`; branch is `(detached)` for detached HEAD; primary is first.
- **`_gwt_worktree_for_branch <branch>`** — prints the worktree path whose branch matches, else non-zero.
- **Session state:** `_GWT_LAST` — path of the worktree `gwa` most recently created/reused this shell; bare `gws`/`gwo` fall back to it when no picker.

### B.2 `gwa` — create/adopt

- Flags: `-c` copy (default action), `-o` open, `-s`/`--switch` cd into the new worktree, `-m`/`--from-main` base a new branch on the local default branch, `--no-fetch` skip the origin refresh this run. `-c`/`-o`/`-s` all set the mutually-exclusive `action`; `-m`/`--no-fetch` are orthogonal. `-m` + explicit start-point → error; `-m` resolves start-point to `${$(_gwt_default_branch)#origin/}`, erroring if undeterminable or no local `refs/heads/<sp>`.
- **Origin refresh** (`GWT_GWA_FETCH` default `1`; `--no-fetch` or `=0` disables): `do_fetch=1` when enabled and not `--no-fetch`. Called via **`_gwt_refresh_origin`** — (a) before `_gwt_pick_branch` in the picker path, and (b) in the named path only when `! git show-ref --verify --quiet refs/heads/<branch>` (skip fetch for a local branch). Closes the footgun where an unfetched `origin/<branch>` would otherwise fall through to "create new branch off HEAD."
- **`_gwt_refresh_origin`**: `git remote get-url origin` fails → return 0 (skip, no remote). Else `git fetch --prune origin` backgrounded (`no_monitor`, output → `mktemp`) with `_gwt_spin $! "refreshing from origin…"`; on non-zero → `_gwt_warn "couldn't refresh from origin (offline?) — using last-known"`. Always returns 0 (non-blocking).
- No branch → picker (`_gwt_pick_branch`) if `_gwt_is_picker_available`, else usage error. ESC (rc 130) → `print -z` reinject; empty → return 0.
- Existing worktree for the branch → reuse (no fail): set `_GWT_LAST`, do the action (open/copy/switch→`cd`), return.
- Post-create action (also the reuse path): `copy` → `_gwt_copy`; `open` → `_gwt_open`; `switch` → `cd "$wt"` (gwa is a function, so it can cd the caller's shell). Default stays put.
- **`_gwt_create_worktree <branch> [start-point]`** routes:
  - local `refs/heads/<branch>` exists → `git worktree add <wt> <branch>` (adopt).
  - else `refs/remotes/origin/<branch>` exists → note it, `git worktree add --track -b <branch> <wt> origin/<branch>`.
  - else new branch → `git worktree add -b <branch> <wt> ${start-point:-HEAD}`; `base` = resolved start-point (symbolic-ref short HEAD, or short SHA if detached).
  - `reply=(<wt> <base>)`; `<base>` empty when adopting (git's own output already reports those).
- **`_gwt_seed_files <src> <dst>`** — for each `$GWT_COPY_FILES` present in `<src>`, `mkdir -p "$dst/${f:h}"` + `cp`.
- Post-create: if `$GWT_POST_INIT_CMD`, `( cd "$wt" && eval "$GWT_POST_INIT_CMD" )`; failure warns but keeps the worktree.
- Output: `worktree: <wt>  (from <base>)` (base only for a new branch).

### B.3 `gws` / `gwo` — switch / open

- Resolve target via `_gwt_worktree_for_branch` (explicit name) or picker (`_gwt_pick -p switch|open`) or `_GWT_LAST`.
- Empty target → usage error; non-existent path → `no worktree at <path>`.
- `gws` → `cd "$wt"`; `-o` also `_gwt_open`. `gwo` → `_gwt_open` only.

### B.4 `gwr` — remove

- Flags: `-d`/`-D` (branch delete, safe/force); any other flag → `passthru` to `git worktree remove`.
- Targets: explicit branch → its worktree; else multi-picker `_gwt_pick -m --skip-current -p remove` (nothing selected → no-op).
- Per target (`label="${wt:t}"`): capture `wt_branch` (for delete) via `git -C "$wt" rev-parse --abbrev-ref HEAD`. Remove:
  - `passthru` present → `git worktree remove "$wt" "${passthru[@]}"` (raw git, explicit flags — no trash/spinner).
  - elif `_gwt_worktree_is_clean "$wt"` → `_gwt_remove_one "$wt" "$label"` (fast trash path + spinner, see B.4a).
  - else → `git worktree remove "$wt"` (git refuses + warns on real changes; no spinner).
- If `-d`/`-D` and branch ≠ HEAD: `unique="$(git rev-list --count HEAD..$wt_branch)"`, `git branch <flag> "$wt_branch"`; `unique==0` → info "no unique commits — nothing was lost".
- Returns 1 if any removal failed.

### B.4a `_gwt_remove_one` — fast removal + in-place spinner

Shared by `gwr` (clean path) and `gwclean`. `$1` = worktree path, `$2` = label.
- Fast path when `command -v "${GWT_TRASH_CMD%% *}"` succeeds: `{ eval "$GWT_TRASH_CMD ${(q)wt}" && git worktree prune; }` — a **move** to trash (metadata op, ~free) then reconcile git's bookkeeping (no targeted prune exists; global prune is harmless). No trash tool → native `git worktree remove --force "$wt"`.
- **Fallback:** if trashing exits non-zero, `_gwt_warn "trash failed — removing directly"` then native `git worktree remove --force`.
- **Spinner:** the removal runs backgrounded (`setopt local_options no_monitor`, output → `mktemp`) with `_gwt_spin $! "removing ${label}…"`. `_gwt_spin` clears the line (`\r\e[K`) and leaves the cursor at col 0; the caller's `_gwt_info "✓ removed ${label}"` then **overwrites that same line** → seamless spinner→checkmark. On failure the captured output is `cat`'d to stderr instead. Non-TTY: no spinner, just the `✓ removed` line (or the error).
- **Safety:** only ever called for worktrees that should be removed (clean, or stale+clean in `gwclean`); dirty/`--force` paths stay raw git so the "refuse dirty" semantics are unchanged.

### B.5 `gwclean` — stale cleanup

- `-n`/`--dry-run`. Empty-worktree check first, then `git fetch --prune --quiet origin` wrapped in `_gwt_spin` ("checking remotes…").
- Scans `${repo_dir}/*(/N)` (managed worktrees only, under `$GWT_WORKTREE_DIR/<repo>`).
- Skip when branch is empty/HEAD/`main`/`master`/default. Keep unless `_gwt_branch_stale`. Dirty → skip w/ reason. Dry → collect into `would`. Else → `_gwt_remove_one "$wt_dir" "${wt_dir:t}"` (prints `✓ removed <name>`) + `git branch -D`, `n_removed++`.
- Summary: dry lists `would` (or "nothing to clean"); real prints the `skipped` list + a tail `gwclean: removed N, skipped M` (the redundant per-item "removed:" list was dropped since each `✓` already showed it). Dry-run returns success only if it would remove something.

### B.6 `gwl` — dashboard (`gwl` / `_gwt_gather_repo`)

- Flags `-a`/`--all`, `-p`/`--paths`. `-a` scans `${GWT_WORKTREE_DIR}/*(/N)` (works anywhere); non-`-a` requires a repo.
- Per repo, computed ONCE: default branch; bulk `for-each-ref` over `refs/heads` with `\x1f`-separated fields (committerdate unix/relative, upstream, track, subject, short sha); bulk `branch --merged <base>` set.
- **Parallel dirty scan:** each worktree's `git --no-optional-locks status --porcelain` runs backgrounded (`setopt local_options no_monitor`, results → temp dir), then `wait`. Wall-time ≈ slowest single scan.
- Sync from `upstream:track`: `gone` / `local` (no upstream) / `synced` / `↑a ↓b`; colored (green ahead/synced, yellow behind, magenta diverged, red gone, dim local/detached).
- Stale = merged-set OR gone, excluding default/`main`/`master`/detached. Markers: `▶` current (`git rev-parse --show-toplevel` match), `⌂` primary (first row).
- Columns padded on plain text via zsh `${(r:N:)…}` then wrapped in color so alignment holds; rows sorted newest-first `${(@On)group}`. Detached HEAD → `git log -1` fallback, sync `-`.
- Color gated on `[[ -t 1 && -z "$NO_COLOR" ]]`. Trailing dim summary: totals, dirty, stale, `(gwclean would remove N)`.

### B.7 `gwp`

Alias: `git worktree prune`.

### B.8 Pickers (fzf; optional)

- **`_gwt_is_picker_available`** — `[[ -t 1 ]] && (( $+commands[fzf] ))`.
- **`_gwt_pick [-m] [--skip-current] [-p prompt]`** — worktrees of the current repo, newest-first; fzf with `--delimiter=$'\t' --with-nth=1` (branch shown, path rides along), preview = `git log --oneline --decorate -20` + `status -s`, `ctrl-/` toggles preview, `${=GWT_PICKER_OPTIONS}` splat, `${multi:+--multi}`. Returns fzf's rc (130 = ESC/^C); emits selected path(s).
- **`_gwt_pick_branch`** — branches WITHOUT a worktree (local heads + `origin/*` without local counterpart, deduped, newest-first, relative date inline). fzf `--print-query`: line 1 = typed query, line 2+ = selection. Selection → adopt highlighted branch; query-only → emit typed name (create). Preview = author + recent commits of the log-ref. rc 130 → abort.
- ESC handling in callers: `[[ $? == 130 ]] && print -z -- "<cmd> <flags> "` re-injects the command line.

### B.9 Editor & clipboard

- **`_gwt_open_cmd <path> [q]`** — substitutes `{}` in `$GWT_OPEN_CMD` (or appends the path if absent). `q` → shell-quote `${(q)…}` (for `eval`); else plain double-quotes (readable, for clipboard).
- **`_gwt_open <path>`** — `eval "$(_gwt_open_cmd "$path" q)"`.
- **`_gwt_copy <path>`** — probe first word of `$GWT_CLIPBOARD_CMD` with `command -v`; missing/empty → silent skip; else `_gwt_open_cmd "$path" | eval "$GWT_CLIPBOARD_CMD"`.

### B.10 Git/branch helpers

- **`_gwt_worktree_is_clean <path>`** — `git status --porcelain -uall`; a line whose path is in `$GWT_COPY_FILES` is ignored; any other change → not clean.
- **`_gwt_default_branch [dir]`** — `symbolic-ref --short refs/remotes/origin/HEAD`, else first existing of `origin/{main,master,trunk,develop}`. Prints as `origin/<b>`.
- **`_gwt_branch_stale <branch> [dir]`** — true if `merge-base --is-ancestor refs/heads/<branch> <default>` (merged/never-diverged) OR `upstream:track` contains `gone`.

### B.11 Logging

- `_gwt_info` → stdout, plain. `_gwt_note` (orange 38;5;208), `_gwt_warn` (yellow 33), `_gwt_error` (red 31) → stderr via `_gwt_emit`.
- `_gwt_emit <ansi> <msg>` → `"<cmd>: <msg>"`, colored on `[[ -t 2 && -z "$NO_COLOR" ]]`.
- `_gwt_cmd` → first non-`_gwt_*` frame in `$funcstack` (the public command), else `gw`.

### B.12 Completion

- Registered only if `compdef` exists: `compdef _gwt_complete_branches gwa`; `compdef _gwt_complete_worktrees gwo gws gwr`.
- `_gwt_complete_branches` — local heads + `refs/remotes` (lstrip=3), `-U` deduped, minus `HEAD`.
- `_gwt_complete_worktrees` — branches that have a worktree; for `gwr` (`$words[1] == gwr`) skip the primary (first row); skip `(detached)`.

### B.13 Doctor (`_gwt_doctor`)

- Required: git `is-at-least 2.7` (parsed from `git --version`); `GWT_WORKTREE_DIR` set + (existing→writable, or nearest existing ancestor writable → "will be created").
- Optional: `fzf`; editor = first word of `$GWT_OPEN_CMD` (`?` if unverifiable); clipboard = first word of `$GWT_CLIPBOARD_CMD`; completion = `$+functions[compdef]`.
- Optional also includes **trash** = first word of `$GWT_TRASH_CMD` probed with `command -v`; present → `✓`, absent → non-failing `?` (speed-up only, never counted as `opt_miss`).
- Summary line first; Required + Optional groups; **Config (effective)** dumps all seven knobs (incl. `GWT_TRASH_CMD`); outside a repo, a non-failing `ℹ` note. Exit `req_fail ? 1 : 0`.

---

## C. Config knobs (defaults + semantics)

| Knob | Default | Semantics |
|---|---|---|
| `GWT_WORKTREE_DIR` | `~/dev/workspace` | base for `<repo>/<branch>` layout |
| `GWT_POST_INIT_CMD` | (empty) | `eval`'d inside each new worktree post-seed |
| `GWT_OPEN_CMD` | `code -n && code -a {}` | `{}`=path (or appended); used by open + clipboard |
| `GWT_CLIPBOARD_CMD` | `pbcopy` | reads stdin; first word probed with `command -v`; `eval`'d |
| `GWT_COPY_FILES` | `(.env)` | seeded into new worktrees; excluded from dirty-detection |
| `GWT_PICKER_OPTIONS` | (empty) | extra fzf options, word-split via `${=…}` |
| `GWT_TRASH_CMD` | auto (`trash` if on PATH, else `''`) | trashes a path for fast `gwr`/`gwclean`; first word probed with `command -v`, then `eval`'d; `''` forces native remove. Auto-detected only when unset (`(( ! ${+GWT_TRASH_CMD} ))`), so an explicit empty value is respected |
| `GWT_GWA_FETCH` | `1` (on) | refresh `origin` before the `gwa` picker/lookup so remote branches are current; `0` disables globally, `gwa --no-fetch` per-run. Checked as `!= 0` |
| `NO_COLOR` | — | any value disables color in `gwl` and messages |

---

## D. Decisions, dispositions & pending

**Decided (this session):**
- **Two PRDs merged → one canonical `gwt-prd.md`;** HOW residue kept here (this file) rather than deleted.
- **`GWT_CLIPBOARD_CMD` implemented** (default `pbcopy`; probe-first-word + `eval`; missing/empty → silent skip).
- **`gwt update`: no verbose flag; version pre-check + spinner; `install.sh` owns the single "updated to" line.**
- **`gwt uninstall` on a dev-link = warn-then-proceed** (clone untouched).
- **`npm run dev` alias** for `scripts/link.sh`.
- **Deprecate superseded npm versions = `<1.1.4`** (old `0.1.x` create-tool + interim `1.1.2`).
- **Fast worktree removal via `GWT_TRASH_CMD`** (auto-detects `trash`): `gwr` clean-path + `gwclean` move-to-trash + `git worktree prune`; native fallback (and on trash failure). Dirty/`--force` stay raw git (safety unchanged). Uniform per-worktree in-place spinner → `✓ removed <name>` for **both** methods.
- **`gwa` refreshes `origin` by default** (`GWT_GWA_FETCH=1`; `--no-fetch` / `=0` off): fetch before the picker, and before resolving a **non-local** named branch (local branch → no fetch). Non-blocking (offline warns + continues; no origin → silent skip). Fixes the footgun where an unfetched `origin/<branch>` became a wrong new branch. Scope: `gwa` only (`gwo`/`gws`/`gwr` untouched; `gwl` freshness deferred; `gwclean` already fetches).

**Out of scope (this iteration):** package.json `engines` (none); full Linux auto-defaults; cross-repo/global `-g`; Tab-opens-picker.

**Pending action:**
- ☐ `npm deprecate "@bojangles/gwt@<1.1.4" "superseded — please use the latest version (npx @bojangles/gwt@latest)"` (needs the maintainer's 2FA OTP).

**Deferred (backlog):** Tab opens the picker · cross-repo/global `-g` · full Linux-aware auto-defaults.

---

## E. Related

- **PRD:** `gwt-prd.md` (WHAT & WHY — the doc this feeds).
- **Next step:** a full Technical Specification via `to-tech-spec`, grounded in `src/gwt.zsh` + `install.sh` + `scripts/link.sh`.
