# PRD — gwt: git-worktree toolkit

> **Feature area:** Developer tooling — git worktree CLI (`gwa` / `gws` / `gwo` / `gwr` / `gwl` / `gwclean` / `gwp` / `gwt`)
> **Status:** Implemented & shipped — describes `@bojangles/gwt` as of 1.1.5 (drafted 2026-07-22)
> **Type:** Product Requirements (WHAT & WHY) — the complete product, verifiable without reading source.
> **Owner:** Bojan Mazej
> **Scope note:** This is the **single, canonical PRD** for gwt. It covers both the **behavior** of every command and the **packaging & distribution** of the tool — install, versioning, update, uninstall, and the development loop. It supersedes the earlier split into a separate behavior PRD and packaging PRD.

## 1. Overview

`gwt` is a **zsh** toolkit that makes git worktrees fast to create, switch to, open, list, and clean up — with short commands and an optional fzf picker, without leaving the shell. A git *worktree* is a second (third, …) working directory attached to the same repository, letting you have several branches checked out at once in separate folders instead of stashing and switching in place.

Raw `git worktree` is verbose and leaves the bookkeeping to you: you choose paths, remember where each worktree lives, `cd` by hand, copy over gitignored files like `.env`, and prune stale ones yourself. `gwt` removes that friction by owning a **predictable layout** and wrapping the common operations in one-word commands:

- **Current state without the tool:** `git worktree add ../some-path branch`, then `cd` manually, then re-create `.env`, then later hunt down and remove merged worktrees by hand. Paths are ad-hoc; nothing tells you which worktrees are dirty or stale.
- **Desired state (this tool):** `gwa branch` creates the worktree in a known place, seeds its gitignored files, and optionally opens it or copies an "open" command; `gws`/`gwo` jump to or open any worktree (with an fzf picker when no name is given); `gwl` shows a status dashboard; `gwr`/`gwclean` remove worktrees safely; and `gwt doctor` verifies the setup.

Every worktree `gwt` creates lives at a single, predictable path derived from the repository name and branch, so all commands can find worktrees without the user tracking paths.

## 2. Goals

1. **One-word, low-friction operations** for the full worktree lifecycle: add, switch, open, remove, list, clean, prune.
2. **A predictable, uniform worktree location** so the user never chooses or remembers paths.
3. **Safe-by-default destructive actions** — removal never silently discards real uncommitted work; branch deletion refuses to lose unmerged commits unless forced.
4. **Fast discovery** — an fzf picker whenever a command is run without a branch name, and a status dashboard that surfaces dirty/stale/sync state at a glance.
5. **Work-context continuity** — gitignored files needed to run a project (e.g. `.env`) are carried into each new worktree; an optional bootstrap command runs after creation.
6. **Graceful degradation** — the tool works with only git + zsh; every optional dependency (fzf, an editor, a clipboard tool, shell completion) enables exactly one feature and its absence is reported, never fatal.
7. **Clear, uniform feedback** — every message is prefixed with the command that produced it; errors are distinct from notes; nothing surfaces a raw `git fatal:` where a friendly message belongs.
8. **One-command install, no privileges** — anyone can install on a clean machine with a single command, no administrator rights, nothing system-wide; re-running it upgrades in place without duplicating shell configuration.
9. **One trustworthy version** — the version the tool reports always equals the version that was installed, maintained in a single place; a from-source/dev build is clearly distinguishable from a release.
10. **Documented update, uninstall, and development loop** — staying current, removing the tool, and hacking on it locally are all one-step and documented.

## 3. Concepts & Vocabulary

These terms are used throughout and appear in the tool's own output:

- **Worktree base folder** — the single directory under which every managed worktree lives (`GWT_WORKTREE_DIR`, default `~/dev/workspace`).
- **Worktree path** — always `<base>/<repo-name>/<branch>`. A branch name containing `/` (e.g. `feature/login`) has its slashes flattened to `-` in the folder name (`feature-login`); the branch itself keeps its real name.
- **Primary (main) worktree** — the repository's original working directory (the one you cloned). It is never removed by the tool and is marked `⌂` in the dashboard.
- **Current worktree** — the one you are standing in; marked `▶` in the dashboard.
- **Adopt vs. create** — creating a worktree for a branch that already exists (locally or on `origin`) *adopts* that branch; giving a new name *creates* a new branch.
- **Default branch** — the repository's main line, detected from the remote's advertised HEAD, else the first of `main`, `master`, `trunk`, `develop` that exists on `origin`.
- **Stale** — a branch whose worktree is a cleanup candidate: it has no commits of its own beyond the default branch (merged or never diverged), **or** its upstream is gone.
- **Clean vs. dirty** — a worktree is *clean* if it has no uncommitted changes **other than** the seeded config files (see `GWT_COPY_FILES`); otherwise *dirty*.
- **Session-last worktree** — the worktree most recently created by `gwa` in the current shell; a bare `gws`/`gwo` falls back to it when no picker is available.
- **Picker** — the interactive fzf list shown when a command needs a branch/worktree and none was given (only when fzf is installed and output is a terminal).

## 4. User Stories

### US-1 — Create (or adopt) a worktree · `gwa`
As a developer, I want one command to spin up a worktree for a branch — new or existing — so that I can work on it in its own folder without manual path juggling.

**Acceptance Criteria**
- `gwa <branch>` creates a worktree at the predictable path for `<branch>` and reports the resulting path.
- If `<branch>` **exists locally**, the worktree adopts that branch.
- If `<branch>` is **not already a local branch**, `gwa` first refreshes from `origin` (unless disabled) so a branch that exists only on the remote is found — this prevents the surprise of silently creating a *new* local branch when the name actually exists on `origin`. (A local branch is adopted directly, with no refresh.)
- If `<branch>` **does not exist locally but exists on `origin`**, the tool announces it is creating from `origin/<branch>` (tracking it) rather than from the current HEAD.
- If `<branch>` **does not exist anywhere**, a new branch is created from the current HEAD (or from the start-point / default branch — see US-2 options), and the output names the base it was cut from.
- If `<branch>` **already has a worktree**, the command does not fail: it reports the existing path and performs the chosen post-action (copy or open) against it.
- A second positional argument sets the **start-point** for a newly created branch.
- After creating, gitignored config files are seeded into the new worktree (US-9) and, if configured, a post-create command runs (US-10).
- By default the "open" command for the new worktree is placed on the clipboard; `-o` opens it in the editor instead.

### US-2 — Choose how a new branch is based · `gwa` flags
As a developer, I want to control what a new branch is based on and what happens after creation, so that the worktree starts from the right commit and opens the way I want.

**Acceptance Criteria**
- `-o` opens the new (or existing) worktree in the editor after creation.
- `-c` (the default) copies a ready-to-run "open" command for the worktree to the clipboard instead of opening it.
- `-s` switches the current shell into the new (or existing) worktree (`cd`) instead of copying or opening. `-c`, `-o`, and `-s` are mutually exclusive; without `-s` the shell stays where it is.
- `-m` (alias `--from-main`) bases a **new** branch on the local **default branch** instead of the current HEAD.
- `-m` combined with an explicit start-point is rejected with a clear error.
- `-m` when the default branch can't be determined, or when there is no local branch of that name, fails with a clear, actionable error (e.g. telling the user to fetch/checkout it first).
- An unknown flag is rejected with a clear error naming the flag.

### US-3 — Adopt or create through a picker · bare `gwa`
As a developer who doesn't remember the exact branch name, I want a searchable list when I run `gwa` with no name, so that I can adopt an existing branch or type a brand-new one.

**Acceptance Criteria**
- Before the list is shown, `gwa` **refreshes from `origin`** (unless disabled) so a teammate's newly-pushed or updated branch appears and is current — no manual `git fetch` needed. A brief progress indicator shows during the refresh; if offline it notes it couldn't refresh and shows the last-known list rather than blocking.
- With no branch name **and** the picker available, `gwa` shows a searchable list of branches that do **not** yet have a worktree — local branches plus `origin/*` branches with no local counterpart, de-duplicated, newest-commit-first, each showing how long ago it was last committed.
- Highlighting an existing entry and confirming **adopts** that branch.
- Typing a name that matches nothing and confirming **creates** it as a new branch.
- Aborting the picker (Esc / Ctrl-C) makes no change and re-injects the typed command onto the prompt so it can be edited and re-run.
- With no branch name **and** no picker available, the command prints a usage error explaining a branch name is required.

### US-4 — Switch to a worktree · `gws`
As a developer, I want to `cd` into any worktree by name or from a list, so that I can move between parallel branches instantly.

**Acceptance Criteria**
- `gws <branch>` changes the current shell's directory to that branch's worktree.
- `gws` with the name of the primary branch jumps to the primary worktree.
- `gws` with no name shows the picker (when available) to choose a worktree; otherwise it falls back to the session-last worktree.
- `-o` additionally opens the chosen worktree in the editor.
- Naming a branch with no worktree, or a path that no longer exists, produces a clear error rather than a raw git error.
- Aborting the picker makes no change and re-injects the command onto the prompt.

### US-5 — Open a worktree in the editor · `gwo`
As a developer, I want to open a worktree in my editor without switching my shell into it, so that I can review or edit another branch while staying where I am.

**Acceptance Criteria**
- `gwo <branch>` opens that branch's worktree using the configured open command.
- `gwo` with no name shows the picker (when available); otherwise it opens the session-last worktree.
- Naming a branch with no worktree, or an empty fallback (no prior `gwa` this session), produces a clear usage error.
- Aborting the picker makes no change and re-injects the command onto the prompt.

### US-6 — Remove a worktree · `gwr`
As a developer, I want to remove a worktree (and optionally its branch) with protection against losing work, so that cleanup is safe and quick.

**Acceptance Criteria**
- `gwr <branch>` removes that branch's worktree; the branch itself is **kept** by default.
- `gwr` with no name shows a **multi-select** picker (when available), excluding the worktree you're standing in; marking several and confirming removes all of them. Selecting nothing is a no-op.
- A worktree that is **clean** (no changes beyond seeded config files) is removed without prompting.
- While a worktree is being removed, a **progress spinner** is shown (`removing <name>…`) that resolves in place to `✓ removed <name>`, so a slow removal never looks frozen. Each worktree in a multi-remove reports its own line.
- Removal is **near-instant when a trash tool is available** (the worktree is moved to the Trash and is recoverable); otherwise it is removed natively. The on-screen behavior (spinner + `✓ removed`) is identical either way.
- A worktree with **real uncommitted changes** is not force-removed — git refuses and warns, and the worktree is kept.
- `-d` also deletes the branch **safely** (git refuses if it has unmerged commits); `-D` deletes the branch **forcibly**.
- When a branch deleted with `-d`/`-D` had no commits of its own, the output states plainly that nothing was lost.
- Any additional git-style flag (e.g. `--force`) is passed straight through to the underlying remove.
- Naming a branch with no worktree produces a clear error.
- Aborting the picker makes no change and re-injects the command onto the prompt.

### US-7 — Clean up stale worktrees · `gwclean`
As a developer, I want a single command that removes worktrees I'm clearly done with, so that my workspace doesn't accumulate merged branches.

**Acceptance Criteria**
- `gwclean` inspects only the worktrees under the managed base folder for the current repo.
- It refreshes remote state first so "gone upstream" is accurate.
- It removes a worktree **only** when its branch is **stale** (merged / never diverged from the default branch, or upstream gone) **and** the worktree is **clean**; on removal it also deletes the branch.
- The primary/default branch (and `main`/`master`) is never removed.
- A stale-but-**dirty** worktree is **skipped** and reported with the reason (uncommitted changes).
- A progress spinner covers the remote refresh (`checking remotes…`) and each removal reports its own `✓ removed <name>` line (using the same fast trash path as `gwr` when available).
- `-n` (alias `--dry-run`) previews exactly what would be removed and removes nothing.
- The output lists what was skipped and ends with a `removed N, skipped M` count (dry-run lists what would be removed).
- With nothing to clean, it says so plainly.

### US-8 — See the state of all worktrees · `gwl`
As a developer, I want a status dashboard of my worktrees, so that I can see at a glance which are dirty, which are behind/ahead, and which are cleanup candidates.

**Acceptance Criteria**
- `gwl` lists the current repo's worktrees, one row each, **newest-commit-first**, with columns: marker, branch, state (dirty/clean), sync vs. upstream, last-commit subject, and how long ago.
- The current worktree and the primary worktree are visually marked (`▶` and `⌂`).
- The sync column distinguishes ahead/behind counts, in-sync, "local" (no upstream), and "gone" (upstream deleted).
- Stale rows (what `gwclean` would target) are marked `⚑ stale` and visually recede.
- `-a` (alias `--all`) shows every repo under the base folder, grouped and labeled, and works from **any** directory (no current repo required).
- `-p` (alias `--paths`) adds each worktree's short commit SHA and full path.
- A summary line reports totals: worktrees (and repos, with `-a`), how many are dirty, how many stale, and how many `gwclean` would remove.
- Color is used on a terminal and suppressed when `NO_COLOR` is set or output is not a terminal.
- A detached-HEAD worktree is listed with its commit info and a neutral sync indicator.

### US-9 — Carry project config into new worktrees · `GWT_COPY_FILES`
As a developer, I want gitignored files my project needs to run (like `.env`) copied into each new worktree, so that a fresh worktree is immediately runnable.

**Acceptance Criteria**
- On creation, each configured file that **exists** in the source worktree is copied into the new worktree at the same relative path (creating any needed parent folders).
- Files that don't exist in the source are silently skipped.
- These seeded files do **not** count as "dirty" for the purposes of clean-detection (so `gwr`/`gwclean` still consider such a worktree clean).
- The default set is a single generic entry (`.env`); the documentation shows how to configure a project-specific list.

### US-10 — Bootstrap a new worktree · `GWT_POST_INIT_CMD`
As a developer, I want an optional command to run inside each newly created worktree, so that dependencies are installed (or any setup runs) automatically.

**Acceptance Criteria**
- When set, the command runs inside the newly created worktree after files are seeded.
- If it fails, the failure is reported but the worktree is kept (not rolled back).
- When unset (the default), nothing runs.

### US-11 — Diagnose the setup · `gwt doctor`
As a user, I want a single command that tells me whether my environment is ready and shows my effective settings, so that I can fix problems before they bite.

**Acceptance Criteria**
- `gwt doctor` reports **required** checks — git at the minimum supported version, and a usable worktree base folder (set, and existing-or-creatable and writable) — each marked pass/fail with a copy-pasteable fix on failure.
- It reports **optional** checks — the picker (fzf), an editor command, a clipboard command, a trash tool (a pure speed-up for removal; its absence is noted but never a failure), and shell completion — each marked available / missing (or "can't verify"), with the single feature each enables.
- It prints a one-line summary first (e.g. "2 required OK, 1 optional missing").
- It shows a **Config (effective)** section listing every configuration value currently in effect (or `<unset>`/`<none>`).
- It runs from **any** directory; outside a git repository it adds an **informational** note to that effect that does **not** count as a failure.
- Its exit status is non-zero if any required check fails, zero otherwise.
- The tooling used only to install the product is **not** a doctor check.

### US-12 — Get help and version · `gwt`, `gwt -h`, `gwt -v`
As a user, I want quick help and a machine-readable version, so that I can learn the commands and check what I'm running.

**Acceptance Criteria**
- `gwt` (bare) prints a header (the version and the worktree base path) followed by the command list.
- `gwt -h` prints the same plus the configuration reference.
- `gwt -v` prints **only** the bare version string (no prefix, no decoration).
- All three work from any directory, with or without a git repository.

### US-13 — Update and uninstall · `gwt update`, `gwt uninstall`
As a user, I want to update to the latest version and to remove the tool cleanly, without remembering the underlying package commands.

**Acceptance Criteria**
- `gwt update` checks the latest published version (showing brief progress while it does); if already current, it says so and makes no changes; otherwise it upgrades and, on success, confirms the version it updated to. On failure it prints a single connectivity-framed message and keeps any underlying output visible. It refuses to run on a development (linked) install, directing the user to update via their clone instead.
- `gwt uninstall` states what it will remove, asks to confirm (default No), then removes the tool's shell-startup entry and its installed files; `-y`/`--yes` skips the prompt. It needs no network. On a development (linked) install it warns first, then removes only the link (the working clone is untouched). After uninstall, the commands remain in the current shell until it is restarted.
- Both work from any directory, with or without a git repository.

### US-14 — Prune stale git bookkeeping · `gwp`
As a developer, I want a shortcut for git's own worktree pruning, so that stale administrative entries are cleared.

**Acceptance Criteria**
- `gwp` runs git's worktree prune, clearing bookkeeping for worktrees whose folders no longer exist.

### US-15 — Tab completion
As a user with shell completion enabled, I want to Tab-complete branch names, so that I don't have to type or remember them.

**Acceptance Criteria**
- `gwa` completes from all branch names (local and remote, de-duplicated, excluding `HEAD`).
- `gwo`, `gws`, `gwr` complete only branches that currently **have** a worktree.
- `gwr` completion excludes the primary worktree's branch (git won't remove the primary).
- When completion isn't set up, commands still work by typing names in full.

### US-16 — Meta-commands anywhere; clear errors for repo commands
As a user, I want help/version/diagnostics/update/uninstall to work from anywhere, and the worktree commands to tell me plainly when I'm not in a repo, so that I'm never confused by a raw git error.

**Acceptance Criteria**
- `gwt`, `gwt -h`, `gwt -v`, `gwt doctor`, `gwt update`, `gwt uninstall` work from any directory.
- Each worktree command (`gwa`, `gws`, `gwo`, `gwr`, `gwclean`, and `gwl` without `-a`) run outside a git repository prints a clear "not inside a git repository" message and exits non-zero — never a raw git error.
- `gwl -a` is exempt: it operates on the base folder and works from anywhere.

### US-17 — Install on a clean machine
As a developer setting up a new machine, I want to install gwt with a single command, so that I can start managing worktrees immediately.

**Acceptance Criteria**
- A single documented command installs the tool and makes all commands available in a **newly opened** shell.
- The install requires **no administrator password** and changes nothing system-wide.
- On completion it prints a short confirmation including the installed version and the next step (open a new shell / reload configuration, then run `gwt doctor`).
- Re-running the install upgrades in place and never adds a second startup-configuration entry (exactly one exists afterward).
- Immediately after install, `gwt doctor` reports the required dependencies as satisfied.

### US-18 — Know the prerequisites up front
As a first-time user, I want to know what must already be present before installing, so that it doesn't fail partway.

**Acceptance Criteria**
- The documentation lists prerequisites, marking which are **required** versus **optional**, mirroring the required/optional split `gwt doctor` uses.
- Anything needed only to *run the installer* (not the tool) is called out separately as install-time-only.

### US-19 — Trust the reported version
As a user, I want the version the tool reports to match what I installed, so that "am I current?" and bug reports are reliable.

**Acceptance Criteria**
- `gwt -v` shows the same version string as the installed release, and the help header shows that same version.
- A copy installed from source (not the official one-command install) is clearly shown as a development build rather than a misleading release number.

### US-20 — Hack on the tool with a live edit loop
As the tool's author/contributor, I want my installed tool to point at my working copy, so that edits take effect in a new shell without reinstalling.

**Acceptance Criteria**
- A documented development mode makes edits to the working copy live in a newly opened shell, with no per-change reinstall.
- A copy used this way reports a development version (per US-19).

### US-21 — Install without the package tooling
As a user who can't or won't use the one-command installer, I want a documented manual/from-source path, so that I'm not blocked.

**Acceptance Criteria**
- The documentation describes cloning the source and sourcing it directly as a supported fallback.
- Installed this way, the tool functions identically (reporting a development version).

## 5. Functional Requirements

**Worktree layout & shared rules**
- **FR-1** Every managed worktree resides at `<GWT_WORKTREE_DIR>/<repo-name>/<branch>`, with `/` in the branch flattened to `-` for the folder name.
- **FR-2** Worktree paths are always derived, never chosen by the user; all commands locate worktrees by consulting git's worktree list, not by remembering paths.
- **FR-3** Every worktree-acting command (`gwa`, `gws`, `gwo`, `gwr`, `gwclean`, and `gwl` without `-a`) must verify it is inside a git repository up front and, if not, emit a single uniform "not inside a git repository" error and a non-zero exit.
- **FR-4** Messages are prefixed with the name of the public command that produced them; informational output goes to standard output, while notes/warnings/errors go to standard error and are colored on a terminal (unless `NO_COLOR`).

**`gwa` — create/adopt**
- **FR-5** `gwa <branch>` creates a worktree for `<branch>`, choosing among: adopt an existing local branch; create-and-track from `origin/<branch>` when only the remote branch exists (announced); or create a new branch from the start-point (default: current HEAD).
- **FR-6** A second positional argument is the start-point for a newly created branch.
- **FR-7** `-m`/`--from-main` bases a new branch on the local default branch; it conflicts with an explicit start-point (error), and fails clearly when the default branch is undeterminable or absent locally.
- **FR-8** If the target branch already has a worktree, `gwa` reports the existing path and performs the post-action there instead of failing.
- **FR-9** After creation, `gwa` seeds `GWT_COPY_FILES` (FR-19), runs `GWT_POST_INIT_CMD` if set (FR-20), records the worktree as the session-last, prints the worktree path (and, for a new branch, the base it was cut from), then performs the post-action: `-c` copy an open-command to the clipboard (default), `-o` open in the editor, or `-s` switch the shell into it (`cd`). Without `-s` the shell does not change directory.
- **FR-10** With no branch name: if the picker is available, show branches without a worktree (local + remote-only, de-duplicated, newest-first) and allow adopt-highlighted or create-typed; if not, print a usage error. Aborting re-injects the command line and changes nothing.
- **FR-10a** By default `gwa` refreshes `origin` (with a progress indicator) so remote branches are current — before the picker list is built, and before resolving a named branch that is **not** already local (a local branch is adopted without refreshing). The refresh is **non-blocking**: if `origin` is unreachable it warns and proceeds with last-known data; if there is no `origin` remote it is skipped silently. It is on by default, disabled globally by `GWT_GWA_FETCH=0` and per-invocation by `gwa --no-fetch`.

**`gws` / `gwo` — switch / open**
- **FR-11** `gws <branch>` changes directory to that worktree; `-o` also opens it. `gws` targeting the primary branch reaches the primary worktree.
- **FR-12** `gwo <branch>` opens that worktree in the editor without changing the shell's directory.
- **FR-13** With no branch name, `gws`/`gwo` use the picker when available, else the session-last worktree; an empty result yields a usage error, and a non-existent path yields a clear error. Aborting the picker changes nothing and re-injects the command line.

**`gwr` — remove**
- **FR-14** `gwr <branch>` removes that branch's worktree and, by default, keeps the branch. With no name, a multi-select picker (excluding the current worktree) removes all marked worktrees; selecting nothing is a no-op.
- **FR-15** A clean worktree (changes limited to seeded files) is removed without prompting; a worktree with real uncommitted changes is not force-removed (git refuses and warns; the worktree stays). Extra git-style flags (e.g. `--force`) pass through to the underlying remove.
- **FR-15a** Removal shows a per-worktree progress spinner that resolves in place to `✓ removed <name>` (TTY only; a slow removal must never appear frozen). When a trash tool is configured (`GWT_TRASH_CMD`, auto-detected), removal moves the worktree to the Trash — near-instant and recoverable — then reconciles git's bookkeeping; otherwise it removes natively. If trashing fails it falls back to native removal (with a brief note). The user-visible behavior is identical for both methods.
- **FR-16** `-d` deletes the branch safely (refused if unmerged); `-D` deletes it forcibly; when the deleted branch had no unique commits, the output says nothing was lost.

**`gwclean` — stale cleanup**
- **FR-17** `gwclean` refreshes remote state (shown with a spinner), then, among the managed worktrees of the current repo, removes those whose branch is stale (merged/never-diverged, or upstream gone) **and** whose worktree is clean, deleting the branch too; it never touches the default/`main`/`master` branch. Each removal uses the same fast/spinner path as `gwr` (FR-15a) and reports a `✓ removed <name>` line. Stale-but-dirty worktrees are skipped with a reason.
- **FR-18** `-n`/`--dry-run` previews removals without changing anything; output summarizes removed/would-remove and skipped, or states there is nothing to clean.

**Config-driven behavior**
- **FR-19** `GWT_COPY_FILES` lists gitignored files to copy from the source worktree into each new worktree (only those that exist; parent folders created). These files are excluded from dirty-detection. Default: `(.env)`.
- **FR-20** `GWT_POST_INIT_CMD`, if set, runs inside each new worktree after seeding; failure is reported but the worktree is kept. Default: none.
- **FR-21** `GWT_OPEN_CMD` is the command used to open a worktree; `{}` is replaced by the worktree path, or the path is appended if `{}` is absent. It is used both to open (`-o`, `gwo`, `gws -o`) and to compose the clipboard "open" command (`-c`). Default: VS Code.
- **FR-22** `GWT_CLIPBOARD_CMD` is the command that receives the open-command on standard input for `-c`; if its program isn't found (or it is empty), the copy is silently skipped. Default: `pbcopy`.
- **FR-23** `GWT_PICKER_OPTIONS` supplies extra options to the picker. `GWT_WORKTREE_DIR` sets the base folder. `GWT_TRASH_CMD` is the command that trashes a path for fast `gwr`/`gwclean` removal — auto-detected (`trash`) when unset, settable to another tool (e.g. `trash-put`, `gio trash`), or empty to force native removal. `GWT_GWA_FETCH` (default on) controls whether `gwa` refreshes `origin` before its picker/lookup (per FR-10a). `NO_COLOR` disables color everywhere.

**`gwl` — dashboard**
- **FR-24** `gwl` renders one row per worktree of the current repo, newest-commit-first, with marker, branch, state, sync, last-commit subject, and relative time; the current (`▶`) and primary (`⌂`) worktrees are marked; stale rows are flagged `⚑ stale` and dimmed.
- **FR-25** `-a`/`--all` renders every repo under the base folder (grouped/labeled) and works from any directory; `-p`/`--paths` adds short SHA and full path. A trailing summary reports worktree/repo counts, dirty, stale, and how many `gwclean` would remove.

**Meta-commands**
- **FR-26** `gwp` runs git's worktree prune.
- **FR-27** `gwt` (bare) shows the header + command list; `gwt -h` adds the configuration reference; `gwt -v` prints only the bare version string.
- **FR-28** `gwt doctor` reports required and optional checks with a summary line, shows effective configuration, runs anywhere (adding a non-failing informational note outside a repo), and exits non-zero only on a required failure.
- **FR-29** `gwt update` and `gwt uninstall` behave as in US-13 and run from anywhere.
- **FR-30** Tab completion offers all branches for `gwa`, and only worktree-backed branches for `gwo`/`gws`/`gwr` (with `gwr` excluding the primary).

**Packaging, install & distribution**
- **FR-31** The tool installs with a **single command** that requires **no administrator privileges** and modifies nothing system-wide; after install the commands are available in newly started interactive shells.
- **FR-32** Installation is **idempotent** — re-running upgrades the installed tool and leaves **exactly one** startup-configuration entry.
- **FR-33** On completion the installer prints a confirmation including the **installed version** and the **next action** (open a new shell / reload, then `gwt doctor`); a first install and an upgrade are distinguishable in that message.
- **FR-34** The **version the tool reports** (`gwt -v` and the help header) equals the **installed version**, maintained as a single source of truth; a from-source/dev copy reports a clearly-marked **development version** instead of a release number.
- **FR-35** The documentation lists **prerequisites** split into required vs optional (mirroring `gwt doctor`), and separately identifies install-time-only prerequisites. The tooling used only to install the product is **not** a runtime dependency and **not** a `gwt doctor` check.
- **FR-36** A **development mode** is documented that points the installed tool at a working clone so edits are live in a new shell without reinstalling; and a **manual / from-source** install is documented as a fallback.
- **FR-37** The installer edits **only** the zsh startup configuration; no other shell is modified.

## 6. Non-Goals (Out of Scope)

- **Not** a general git wrapper — it manages worktrees, not commits, merges, rebases, or PRs.
- **No** support for shells other than zsh.
- **No** cross-repo / global switching (jumping to another repository's worktree from anywhere) beyond `gwl -a`'s read-only listing.
- **No** tmux/window/pane orchestration and **no** LLM-generated branch names or commit messages.
- **No** merge/PR lifecycle commands (e.g. a "merge and clean up" flow).
- **Not** a rewrite in another language — it stays a sourced zsh toolkit; and **not** distributed as a system-PATH binary or subprocess (a child process cannot `cd` the parent shell or define its interactive commands, which is the whole point).
- **No** version-syncing machinery — the version has a single source that the installer stamps in; releasing is a manual version bump.
- The picker is **fzf-specific**; other fuzzy finders are out of scope this iteration.
- **Not** full cross-platform: macOS-primary; Linux users configure `GWT_OPEN_CMD`, `GWT_CLIPBOARD_CMD`, and (if their trash tool isn't named `trash`) `GWT_TRASH_CMD` themselves (no OS auto-detection beyond looking for a `trash` binary this iteration).

## 7. Visual / Observable Behavior

- **Dashboard (`gwl`):** a bold header row (BRANCH, STATE, SYNC, LAST COMMIT, WHEN — plus COMMIT and PATH with `-p`); each worktree on its own aligned row prefixed by `▶` (current), `⌂` (primary), or blank. Sync renders as `↑<n> ↓<n>`, `synced`, `local`, `gone`, or `-` (detached), color-coded (green ahead/synced, yellow behind, magenta diverged, red gone, dim local/none). Stale rows show a trailing `⚑ stale` and are dimmed. Rows are ordered newest-commit-first. A dim summary line closes the output. With `-a`, repos appear as labeled groups separated by a blank line.
- **Doctor (`gwt doctor`):** a summary line first, then a **Required** group and an **Optional** group, each entry marked `✓` (pass), `✗` (fail, with a copy-pasteable fix), or `?` (present but not statically verifiable); then a **Config (effective)** block listing each setting's value; and, outside a repo, a trailing `ℹ` note that the current directory isn't a git repository.
- **Pickers:** an fzf list showing the branch (with relative date on the branch picker), a live preview pane (recent commits + status for worktrees; author + recent commits for the branch picker), `ctrl-/` to toggle the preview, and a header describing the keys. The remove picker supports multi-select (Tab to mark). Aborting (Esc/Ctrl-C) leaves the typed command on the prompt for editing.
- **`gwa` output:** git's own "Preparing worktree…" line, then `worktree: <path>` (with `(from <base>)` for a newly cut branch); adoption from a remote is announced beforehand; reusing an existing worktree reports its path.
- **Removal progress:** a braille spinner on a single line (`⠹ removing <name>…`) that is overwritten in place by `✓ removed <name>` the instant it finishes — the same line, no lingering spinner. Identical whether the removal trashed (near-instant) or removed natively (slower); on a non-terminal there is no spinner, just the `✓ removed <name>` line.
- **Messages:** `<command>: <message>` form; errors in red, notes in orange, warnings in yellow (on a terminal). Informational output is plain on standard output.
- **Version (`gwt -v`):** the bare version string alone (e.g. `1.1.5`); a development/linked build reports a clearly-marked development version.

## 8. Success Metrics

- **Path-free operation:** a user completes create → switch → open → remove without ever typing or seeing an ad-hoc worktree path they had to choose.
- **Safety:** no invocation of `gwr`/`gwclean` removes a worktree with real uncommitted changes, and no branch with unmerged commits is deleted without an explicit force flag.
- **Degradation:** with fzf / editor / clipboard / completion each individually absent, all core commands still function and `gwt doctor` reports exactly which single feature is degraded.
- **Uniform errors:** running any worktree command outside a repository yields the friendly message, never a raw `git fatal:`.
- **Dashboard accuracy:** `gwl`'s dirty/stale/sync indicators match what `gwr`/`gwclean` would actually do (the stale count equals `gwclean`'s removable set for clean worktrees).
- **Clean-machine install:** on a fresh zsh machine with only the required prerequisites, the one-command install succeeds, a new shell exposes all commands, and `gwt doctor` passes with no required failures.
- **Version parity & idempotency:** `gwt -v` equals the installed release version in every released install, and any number of re-installs leaves exactly one startup-configuration entry.
- **No privilege escalation:** install completes with zero administrator/password prompts.

## 9. Related Documents

- **HOW-level companion:** `gwt_tech-spec-inputs.md` — raw material for the Technical Specification: the installer mechanism, version stamping, shell-config wiring/removal, dev-link safety, and the git plumbing behind every command. Everything that must **not** live in this PRD.
- **Implementation:** the tool lives in this repository — `src/gwt.zsh` (the plugin), `install.sh` (the one-command installer), and `scripts/link.sh` (the development-mode linker). This PRD describes their observable behavior as of 1.1.5.
- **User-facing documentation:** `README.md` — install, commands, configuration, update/uninstall, and the development loop.

_This single PRD supersedes the earlier split into `gwt-extraction-prd.md` (packaging) and a separate behavior PRD; the HOW residue previously in `gwt-extraction_tech-spec-inputs.md` now lives in `gwt_tech-spec-inputs.md`._
