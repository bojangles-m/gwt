# ---------------------------------------------------------------------------
# Configuration — user-settable knobs (export before the shell loads)
# ---------------------------------------------------------------------------

GWT_VERSION="0.0.0-dev"   # release version is stamped in here by install.sh

# base dir for `gwx -d` detached logs.
GWT_EXEC_LOG_DIR="$HOME/.gwt/logs"

# ---------------------------------------------------------------------------
# All worktrees live under $GWT_WORKTREE_DIR/<repo-name>/<branch>.
# Shell control: export GWT_WORKTREE_DIR='$HOM/<repo-name>/<branch>'
# ---------------------------------------------------------------------------
: ${GWT_WORKTREE_DIR:="$HOME/dev/workspace"}

# ---------------------------------------------------------------------------
# Command run inside each new worktree after creation, e.g. 'pnpm install'.
# Default Empty = do nothing.
# Shell control: export GWT_POST_INIT_CMD='pnpm install'
# ---------------------------------------------------------------------------
: ${GWT_POST_INIT_CMD:=""}

# ---------------------------------------------------------------------------
# Command used to open a worktree ({} = its path; if absent, the path is appended)
# Default is VS Code.
# Shell control: export GWT_OPEN_CMD='cursor {}'
# ---------------------------------------------------------------------------
: ${GWT_OPEN_CMD:='code -n && code -a {}'}

# ---------------------------------------------------------------------------
# Command that reads stdin and writes it on the clipboard.
# Shell control: export GWT_CLIPBOARD_CMD='xclip -selection clipboard' // Linux
# ---------------------------------------------------------------------------
: ${GWT_CLIPBOARD_CMD:='pbcopy'}

# ---------------------------------------------------------------------------
# Gitignored files copied into each new worktree (only the ones that exist).
# Worktrees don't inherit gitignored files, so untracked ones (e.g. .env) are copied.
# Shell control: export GWT_COPY_FILES=(.env .npmrc application/config/config.php)
# ---------------------------------------------------------------------------
(( ${+GWT_COPY_FILES} )) || GWT_COPY_FILES=(.env)

# ---------------------------------------------------------------------------
# Interactive picker by fzf (used only if installed).
# Shell control: export GWT_PICKER_OPTIONS='--height=60% --preview-window=down'
# ---------------------------------------------------------------------------
: ${GWT_PICKER_OPTIONS:=""}

# ---------------------------------------------------------------------------
# Command that moves a worktree to the trash
# Shell control: export GWT_TRASH_CMD='gio trash'
# ---------------------------------------------------------------------------
if (( ! ${+GWT_TRASH_CMD} )); then
    (( $+commands[trash] )) && GWT_TRASH_CMD='trash' || GWT_TRASH_CMD=''
fi

# ---------------------------------------------------------------------------
# Refresh origin before the `gwa` picker / name lookup, so the other branch 
# from origin shows up. 
# Shell control: export GWT_GWA_FETCH=0 (1 = on (default), 0 = off)
# ---------------------------------------------------------------------------
: ${GWT_GWA_FETCH:=1}


# ---------------------------------------------------------------------------
# Public commands
# ---------------------------------------------------------------------------

alias gwp='git worktree prune'

# Help + meta-commands. All of these work anywhere (no git repo required).
#   gwt          commands only        gwt -h        commands + configuration
#   gwt -v       version (bare)       gwt doctor    setup diagnostics
#   gwt update   upgrade to latest    gwt uninstall remove gwt (asks first)
function gwt() {
    [[ "$1" == -v ]]        && { print -r -- "$GWT_VERSION"; return; }   # bare version — machine-readable
    [[ "$1" == doctor ]]    && { _gwt_doctor; return; }
    [[ "$1" == update ]]    && { shift; _gwt_update "$@"; return; }
    [[ "$1" == uninstall ]] && { shift; _gwt_uninstall "$@"; return; }
    _gwt_help_header                               # banner on every help mode
    case "$1" in
        -h) _gwt_help; echo; _gwt_help_config ;;   # -h: everything (commands + config)
        *)  _gwt_help; echo ;;                      # bare: commands only
    esac
}

function _gwt_help_header() {
    cat <<EOF
gwt: v$GWT_VERSION
Worktrees are created under: $GWT_WORKTREE_DIR/<repo>/<branch>

EOF
}

function _gwt_help() {
    cat <<EOF
Usage:
  gwa [-c | -o | -s] [-m | --from-main] [--no-fetch] [<branch>] [<start-point>]
      Create a new worktree. No <branch>: fzf picker — pick an existing branch to adopt,
      or type a new name and press enter to create it.
          -c    Copy the "open" command to the clipboard (default)
          -o    Open the worktree in your editor (\$GWT_OPEN_CMD — VS Code by default)
          -s    Switch into the new worktree (cd)
          -m    Base a NEW branch on the local default branch (main) instead of the
                current HEAD. Ignored if <branch> already exists.
          --no-fetch  Skip the origin refresh for this run (see GWT_GWA_FETCH)

  gwo [<branch>]                    Open a worktree in your editor. No <branch>: fzf picker (else the most recent).
  gws [-o] [<branch>]               Switch to a worktree (cd). No <branch>: fzf picker; -o also opens it in your editor.

  gwx [-d | --detach] [-a | --all] [<branch>] -- <command>
      Run a command inside a worktree without cd-ing there. No <branch>: fzf picker.
      Everything after -- runs verbatim; output streams live and the exit code passes through.
          -d    Detach: run in the background (survives the terminal). Output is logged to
                $GWT_EXEC_LOG_DIR/<repo>/<branch>.log — tail -f it to watch.
          -a    Run in ALL worktrees of this repo (parallel; continues on error, then a
                summary). Combine with -d (gwx -da) to background one job per worktree.

  gwr [-d | -D] [<branch>] [--force]
      Remove a worktree. The branch is KEPT unless you pass -d/-D.
      No <branch>: fzf multi-picker (mark several with Tab, remove all).
          -d    Also delete the branch — safe: git refuses if it has unmerged commits.
                (A branch with no commits of its own is deleted; nothing is lost.)
          -D    Also delete the branch — force: deletes even with unmerged commits.

  gwclean [-n | --dry-run]
      Remove stale worktrees: branches with no unique commits (merged/never diverged) or deleted remotes.
      Branches with unpushed/unmerged commits are KEPT — use gwr for those.
          -n    Dry run: preview what would be removed; removes nothing.

  gwl [-a | --all] [-p | --paths] [-b | --base]
      Worktree status dashboard: branch, dirty, ahead/behind, last commit.
      ⚑ stale marks branches gwclean would remove.
      Short flags bundle: gwl -abp == -a -b -p.
          -a    Show every repo under \$GWT_WORKTREE_DIR (works from any directory)
          -p    Also show each worktree's path + short SHA
          -b    Show what each NEW branch was cut from (— if unknown)

  gwp                               Prune stale worktree entries.
  gwt doctor                        Check your setup — required + optional deps + effective config, with fixes.
  gwt update                        Update gwt to the latest published version.
  gwt uninstall                     Remove gwt (asks for confirmation first).
  gwt [-h | -v]                     Help: bare = commands · -h = commands + configuration · -v = version.
EOF
}

function _gwt_help_config() {
    cat <<EOF
Configuration:
  Set these in your shell (or ~/.zshrc). They affect the next \`gwa\` command.
        GWT_WORKTREE_DIR            base folder that holds all worktrees
                                    e.g.  export GWT_WORKTREE_DIR=~/dev/wt
        GWT_COPY_FILES              gitignored files copied into each new worktree (if present)
                                    e.g.  GWT_COPY_FILES=(.env .npmrc)   # in this file
        GWT_POST_INIT_CMD           command run inside the new worktree after it is created
                                    e.g.  GWT_POST_INIT_CMD='pnpm install' gwa my-branch
        GWT_OPEN_CMD                command used to open a worktree ({} = its path)
                                    default: code -n && code -a {}
                                    e.g.  export GWT_OPEN_CMD='cursor {}'
        GWT_CLIPBOARD_CMD           command that reads stdin -> clipboard (gwa -c)
                                    default: pbcopy (macOS)
                                    e.g.  export GWT_CLIPBOARD_CMD='xclip -selection clipboard'
        GWT_PICKER_OPTIONS          fzf options for the interactive branch picker (if installed)
                                    e.g.  export GWT_PICKER_OPTIONS='--height=60% --preview-window=down'
        GWT_TRASH_CMD               command to trash a path — fast gwr/gwclean (auto-detects \`trash\`)
                                    e.g.  export GWT_TRASH_CMD='trash-put'   # or '' to force native
        GWT_GWA_FETCH               refresh origin before the gwa picker/lookup (1=on default, 0=off)
                                    e.g.  export GWT_GWA_FETCH=0             # or per-run: gwa --no-fetch
EOF
}

# ---------------------------------------------------------------------------
# Doctor — environment & config diagnostics (read-only; suggests, never fixes)
# ---------------------------------------------------------------------------
# gwt doctor: report required + optional dependencies, each ✓/✗/? with a copy-pasteable fix.
function _gwt_doctor() {
    local g="" r="" y="" bld="" x=""
    if [[ -t 1 ]]; then g=$'\e[32m' r=$'\e[31m' y=$'\e[33m' bld=$'\e[1m' x=$'\e[0m'; fi
    local ok="${g}✓${x}" bad="${r}✗${x}" maybe="${y}?${x}"

    local -a req opt
    local req_ok=0 req_fail=0 opt_miss=0

    # --- Required: git >= 2.7 (worktree / --porcelain / for-each-ref formats) ---
    autoload -Uz is-at-least
    local gv="${$(git --version 2>/dev/null)##git version }"; gv="${gv%% *}"
    if [[ -n "$gv" ]] && is-at-least 2.7 "$gv"; then
        req+=("  $ok  git $gv"); (( req_ok++ ))
    elif [[ -n "$gv" ]]; then
        req+=("  $bad  git $gv   need >= 2.7 (worktree/porcelain).   Fix: upgrade git"); (( req_fail++ ))
    else
        req+=("  $bad  git not found.   Fix: xcode-select --install"); (( req_fail++ ))
    fi

    # --- Required: GWT_WORKTREE_DIR set + exists-or-creatable (never created here) ---
    local d="$GWT_WORKTREE_DIR"
    if [[ -z "$d" ]]; then
        req+=("  $bad  GWT_WORKTREE_DIR  empty.   Fix: export GWT_WORKTREE_DIR=~/dev/workspace"); (( req_fail++ ))
    elif [[ -d "$d" ]]; then
        if [[ -w "$d" ]]; then
            req+=("  $ok  GWT_WORKTREE_DIR=$d  (exists, writable)"); (( req_ok++ ))
        else
            req+=("  $bad  GWT_WORKTREE_DIR=$d  not writable.   Fix: fix perms or pick another path"); (( req_fail++ ))
        fi
    else
        local anc="$d"; while [[ ! -d "$anc" ]]; do anc="${anc:h}"; done
        if [[ -w "$anc" ]]; then
            req+=("  $ok  GWT_WORKTREE_DIR=$d  (will be created)"); (( req_ok++ ))
        else
            req+=("  $bad  GWT_WORKTREE_DIR=$d  can't create ($anc not writable).   Fix: pick a writable path"); (( req_fail++ ))
        fi
    fi

    # --- Optional: each ✗ degrades one feature; ? = can't verify statically ---
    if (( $+commands[fzf] )); then
        opt+=("  $ok  fzf         interactive pickers")
    else
        opt+=("  $bad  fzf         pickers off — type branch names.   Fix: brew install fzf"); (( opt_miss++ ))
    fi

    local -a _tok; _tok=(${(z)GWT_OPEN_CMD}); local ed="${_tok[1]}"
    if [[ -n "$ed" ]] && (( $+commands[$ed] )); then
        opt+=("  $ok  editor      '$ed'  (gwo / -o)")
    else
        opt+=("  $maybe  editor      can't verify GWT_OPEN_CMD='$GWT_OPEN_CMD' — tried when you open")
    fi

    local clip="${GWT_CLIPBOARD_CMD%% *}"
    if [[ -n "$clip" ]] && (( $+commands[$clip] )); then
        opt+=("  $ok  clipboard   '$clip'  (gwa -c)")
    else
        opt+=("  $bad  clipboard   gwa -c skipped — set GWT_CLIPBOARD_CMD (e.g. xclip, wl-copy)"); (( opt_miss++ ))
    fi

    if (( $+functions[compdef] )); then
        opt+=("  $ok  completion  Tab")
    else
        opt+=("  $bad  completion  off — ensure 'compinit' runs in your zsh setup"); (( opt_miss++ ))
    fi

    # trash is a pure speed-up (fast gwr/gwclean); its absence is not a failure.
    local trash="${GWT_TRASH_CMD%% *}"
    if [[ -n "$trash" ]] && command -v "$trash" >/dev/null; then
        opt+=("  $ok  trash       '$trash'  (fast gwr/gwclean)")
    else
        opt+=("  $maybe  trash       gwr/gwclean use git (slower) — set GWT_TRASH_CMD for fast removal")
    fi

    # --- Summary line (first), then the two groups ---
    local sreq sopt scol="$bld"
    if (( req_fail )); then sreq="${req_fail} required FAILING"; scol="${bld}${r}"
    else                    sreq="${req_ok} required OK"; fi
    if (( opt_miss )); then sopt="${opt_miss} optional missing"
    else                    sopt="all optional available"; fi
    print -r -- "${scol}${sreq}, ${sopt}${x}"
    print -r --
    print -r -- "Required"; print -rl -- $req
    print -r --
    print -r -- "Optional"; print -rl -- $opt

    # --- Config (effective values) ---
    print -r --
    print -r -- "${bld}Config (effective)${x}"
    print -rl -- \
        "  GWT_WORKTREE_DIR    ${GWT_WORKTREE_DIR:-<unset>}" \
        "  GWT_OPEN_CMD        ${GWT_OPEN_CMD:-<unset>}" \
        "  GWT_CLIPBOARD_CMD   ${GWT_CLIPBOARD_CMD:-<unset>}" \
        "  GWT_COPY_FILES      ${GWT_COPY_FILES[*]:-<none>}" \
        "  GWT_POST_INIT_CMD   ${GWT_POST_INIT_CMD:-<none>}" \
        "  GWT_PICKER_OPTIONS  ${GWT_PICKER_OPTIONS:-<none>}" \
        "  GWT_TRASH_CMD       ${GWT_TRASH_CMD:-<none>}" \
        "  GWT_GWA_FETCH       ${GWT_GWA_FETCH:-<unset>}"

    # --- Context (informational only; never a required failure) ---
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print -r --
        print -r -- "  ${y}ℹ${x}  not inside a git repository (gwa/gws/gwo/gwr need one)"
    fi

    return $(( req_fail ? 1 : 0 ))
}

# ---------------------------------------------------------------------------
# Self-management — update / uninstall (meta-commands; run anywhere, no repo)
# ---------------------------------------------------------------------------

function _gwt_spin() {
    local pid=$1 msg=$2
    if [[ -t 1 ]]; then
        local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏) i=1
        while kill -0 $pid 2>/dev/null; do
            printf '\r%s %s' "${frames[i]}" "$msg"
            i=$(( i % $#frames + 1 ))
            sleep 0.1
        done
        printf '\r\e[K'          # clear the spinner line
    fi
    wait $pid 2>/dev/null
}

# gwt update — upgrade to the latest published version. First checks the latest
# published version (fresh, bypassing npm's cache); if you're already on it (or
# ahead), it just says so and stops. Otherwise it re-runs the npx installer, whose
# output (download notice / "Ok to proceed?" prompt) streams as-is.
function _gwt_update() {
    (( $# )) && { _gwt_error "unexpected argument: $1  (usage: gwt update)"; return 1; }

    local dest="$HOME/.gwt/gwt.zsh"
    if [[ -L "$dest" ]]; then
        _gwt_error "dev-link install — update with 'git pull' in your clone, not 'gwt update'"
        return 1
    fi

    # What's the newest published version? --prefer-online so a stale cache can't lie.
    # The check is a silent network call, so run it in the background with a spinner.
    local current="$GWT_VERSION" latest tmp
    setopt local_options no_monitor
    tmp="$(mktemp "${TMPDIR:-/tmp}/gwt.XXXXXX")"
    npm view @bojangles/gwt version --prefer-online >"$tmp" 2>/dev/null &
    _gwt_spin $! "checking for the latest version…"
    latest="$(<$tmp)"; rm -f "$tmp"
    [[ -z "$latest" ]] && { _gwt_error "couldn't reach npm — check your connection"; return 1; }

    autoload -Uz is-at-least
    if is-at-least "$latest" "$current"; then
        _gwt_info "✓ you have the latest version ($current)"
        return 0
    fi

    # install the new version
    npx @bojangles/gwt@latest || { _gwt_error "update failed — see the npx output above"; return 1; }
}

# gwt uninstall — remove gwt: the '# gwt' marker block from ~/.zshrc + ~/.gwt.
# Asks to confirm ([y/N], default No) unless -y/--yes. No network/Node. On a
# dev-link install it warns first, then proceeds (removes the link, not the clone).
function _gwt_uninstall() {
    local yes="" a
    for a in "$@"; do
        case "$a" in
            -y|--yes) yes=1 ;;
            *) _gwt_error "unknown flag: $a  (usage: gwt uninstall [-y])"; return 1 ;;
        esac
    done

    local rc="$HOME/.zshrc" dest="$HOME/.gwt"
    _gwt_info "gwt uninstall will remove:"
    _gwt_info "  • the '# gwt' block from $rc"
    _gwt_info "  • $dest"
    [[ -L "$dest/gwt.zsh" ]] && _gwt_info "  (dev-link install: removes the symlink + line; your clone is untouched)"

    if [[ -z "$yes" ]]; then
        local ans
        read "ans?Proceed? [y/N] "
        [[ "$ans" == [yY]* ]] || { _gwt_info "cancelled — nothing removed"; return 0; }
    fi

    # Remove the marker line '# gwt (git worktree toolkit)' and the source line after it.
    if [[ -f "$rc" ]]; then
        local tmp
        tmp="$(mktemp "${TMPDIR:-/tmp}/gwt-zshrc.XXXXXX")" || { _gwt_error "could not create a temp file"; return 1; }
        awk '
            /^# gwt \(git worktree toolkit\)$/ { skip = 2 }
            skip > 0 { skip--; next }
            { print }
        ' "$rc" > "$tmp" && cat "$tmp" > "$rc"
        rm -f "$tmp"
    fi

    rm -rf "$dest"
    _gwt_info "✓ gwt uninstalled. The commands stay in this shell until you restart it."
}

# Refresh origin so the gwa picker / name lookup see current branches. Non-blocking:
# no `origin` remote → skip silently; a failed fetch (offline) → warn and carry on.
function _gwt_refresh_origin() {
    git remote get-url origin >/dev/null 2>&1 || return 0   # no origin → nothing to refresh
    local tmp
    setopt local_options no_monitor
    tmp="$(mktemp "${TMPDIR:-/tmp}/gwt-fetch.XXXXXX")" || return 0
    git fetch --prune origin >"$tmp" 2>&1 &
    _gwt_spin $! "refreshing from origin…"
    (( $? )) && _gwt_warn "couldn't refresh from origin (offline?) — using last-known"
    rm -f "$tmp"
    return 0
}

# Worktree at $GWT_WORKTREE_DIR/<repo>/<branch>
# gwa [-c | -o | -s] [-m] [--no-fetch] [<branch>] [<start-point>]
#   -c : copy the open-command ($GWT_OPEN_CMD) to the clipboard (default)
#   -o : open the new worktree via $GWT_OPEN_CMD
#   -s : switch into the new worktree (cd)
#   -m : base a NEW branch on the local default branch instead of HEAD (--from-main)
#   --no-fetch : skip the origin refresh for this run (see GWT_GWA_FETCH)
# With no <branch>: fzf picker — adopt an existing branch, or type a new name to create it.
function gwa() {
    _gwt_require_repo || return 1
    local -a flags pos
    local action="copy"                      # default; -c/-o/-s pick the post-create action
    local from_main="" no_fetch=""
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -c) action="copy" ;;
            -o) action="open" ;;
            -s|--switch) action="switch" ;;
            -m|--from-main) from_main=1 ;;
            --no-fetch) no_fetch=1 ;;
            *)  _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done
    # Refresh origin by default (GWT_GWA_FETCH); --no-fetch skips it for this run.
    local do_fetch=""; [[ "$GWT_GWA_FETCH" != 0 && -z "$no_fetch" ]] && do_fetch=1

    local branch="${pos[1]}" startpoint="${pos[2]}"
    if [[ -n "$from_main" ]]; then
        [[ -n "$startpoint" ]] && { _gwt_error "-m conflicts with an explicit <start-point>"; return 1; }
        startpoint="${$(_gwt_default_branch)#origin/}"   # local default branch, e.g. main
        [[ -z "$startpoint" ]] && { _gwt_error "could not determine the default branch"; return 1; }
        git show-ref --verify --quiet "refs/heads/$startpoint" \
            || { _gwt_error "no local '$startpoint' branch to base on — fetch/checkout it first"; return 1; }
    fi
    if [[ -z "$branch" ]]; then
        # No branch given: pick an existing branch that has no worktree yet.
        if _gwt_is_picker_available; then
            [[ -n "$do_fetch" ]] && _gwt_refresh_origin      # freshen origin/* so the picker is current
            branch="$(_gwt_pick_branch)" || { [[ $? == 130 ]] && print -z -- "${0}${flags:+ $flags} "; return 0; }   # ESC -> reinject cmd
            [[ -z "$branch" ]] && return 0
        else
            _gwt_error "usage: [-c|-o|-s] <branch> [<start-point>]"
            return 1
        fi
    elif [[ -n "$do_fetch" ]] && ! git show-ref --verify --quiet "refs/heads/$branch"; then
        _gwt_refresh_origin      # named branch isn't local — freshen so origin/<branch> can be adopted
    fi

    local src
    src="$(git rev-parse --show-toplevel)"   # current checkout, source of seed files

    # If this branch already has a worktree, reuse it instead of failing.
    local existing
    existing="$(_gwt_worktree_for_branch "$branch")"
    if [[ -n "$existing" ]]; then
        _GWT_LAST="$existing"
        case "$action" in
            open)   _gwt_info "'$branch' already has a worktree at $existing — opening it"
                    _gwt_open "$existing" ;;
            switch) _gwt_info "'$branch' already has a worktree at $existing — switching to it"
                    cd "$existing" ;;
            copy)   _gwt_info "'$branch' already has a worktree at $existing"
                    _gwt_copy "$existing" ;;
        esac
        return 0
    fi

    local -a reply
    _gwt_create_worktree "$branch" "$startpoint" || return 1
    local wt="${reply[1]}" base="${reply[2]}"
    _gwt_seed_files "$src" "$wt"

    # record what a NEW branch was cut from
    [[ -n "$base" ]] && git config "branch.${branch}.gwtBase" "$base" 2>/dev/null

    # Remember the most recent worktree so a bare `gwo` can reopen it.
    _GWT_LAST="$wt"

    # git already prints "Preparing worktree (new branch 'x')"; we add only the base
    # a NEW branch was cut from (empty otherwise, so nothing duplicative is shown).
    _gwt_info "worktree: $wt${base:+  (from $base)}"

    # Optional shell-controlled bootstrap (e.g. GWT_POST_INIT_CMD='pnpm install').
    if [[ -n "$GWT_POST_INIT_CMD" ]]; then
        ( cd "$wt" && eval "$GWT_POST_INIT_CMD" ) \
            || _gwt_error "post-create command failed — worktree kept at $wt"
    fi

    case "$action" in
        copy)   _gwt_copy "$wt" ;;
        open)   _gwt_open "$wt" ;;
        switch) cd "$wt" ;;
    esac
}


# Open a worktree via $GWT_OPEN_CMD (VS Code by default).
# With no <branch>: fzf picker if available, else the worktree gwa created most
# recently in this shell ($_GWT_LAST).
# gwo [<branch>]
function gwo() {
    _gwt_require_repo || return 1
    local wt
    if [[ -n "$1" ]]; then
        wt="$(_gwt_worktree_for_branch "$1")"     # real path from git worktree list
        [[ -n "$wt" ]] || { _gwt_error "no worktree for branch '$1'"; return 1; }
    elif _gwt_is_picker_available; then
        wt="$(_gwt_pick -p 'open')" || { [[ $? == 130 ]] && print -z -- "$0 "; return 0; }   # ESC -> reinject cmd
    else
        wt="$_GWT_LAST"
    fi
    if [[ -z "$wt" ]]; then
        _gwt_error "usage: <branch>   (or run gwa first, then bare gwo)"
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        _gwt_error "no worktree at $wt"
        return 1
    fi
    _gwt_open "$wt"
}

# Switch to a worktree (cd). Without <branch>: fzf picker if available, else the
# most recently created worktree ($_GWT_LAST). With -o, also open it in the editor.
# gws [-o] [<branch>]
function gws() {
    _gwt_require_repo || return 1
    local -a flags pos
    local open=""
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -o) open=1 ;;
            *)  _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done

    local wt
    if [[ -n "${pos[1]}" ]]; then
        wt="$(_gwt_worktree_for_branch "${pos[1]}")"     # real path from git worktree list
        [[ -n "$wt" ]] || { _gwt_error "no worktree for branch '${pos[1]}'"; return 1; }
    elif _gwt_is_picker_available; then
        wt="$(_gwt_pick -p 'switch')" || { [[ $? == 130 ]] && print -z -- "${0}${flags:+ $flags} "; return 0; }   # ESC -> reinject cmd
    else
        wt="$_GWT_LAST"
    fi
    if [[ -z "$wt" ]]; then
        _gwt_error "usage: [-o] <branch>   (or run gwa first, then bare gws)"
        return 1
    fi
    if [[ ! -d "$wt" ]]; then
        _gwt_error "no worktree at $wt"
        return 1
    fi
    cd "$wt"
    [[ -n "$open" ]] && _gwt_open "$wt"     # -o: also open in $GWT_OPEN_CMD
}

# ---------------------------------------------------------------------------
# gwx — run a command inside a worktree without cd-ing there ("exec").
# gwx [-d | --detach] [-a | --all] [<branch>] -- <command> [args…]
#   No <branch>: fzf picker (single-select) to choose the worktree.
#   -a/--all: run in every worktree of this repo (parallel; continue on error + summary).
#   Everything after `--` is the command, run VERBATIM (direct argv, no shell).
#     Need a pipe/chain? gwx <b> -- zsh -c 'a | b'.
#   Default (attached): streams live, stdin/TTY connected, exit code passes through.
#   -d/--detach: run in the background (disowned — survives the terminal closing);
#     output → $GWT_EXEC_LOG_DIR/<repo>/<worktree>.log.  -da: one background job per worktree.
# ---------------------------------------------------------------------------
function gwx() {
    _gwt_require_repo || return 1

    # Split argv at the first `--`: left = flags + <branch>, right = command (verbatim).
    local -a pre cmd
    local sep="" a
    for a in "$@"; do
        if [[ -z "$sep" && "$a" == "--" ]]; then sep=1; continue; fi
        if [[ -n "$sep" ]]; then cmd+=("$a"); else pre+=("$a"); fi
    done
    [[ -n "$sep" ]] || { _gwt_error "missing '--' — usage: gwx [-d] [<branch>] -- <command>"; return 1; }
    (( ${#cmd} ))   || { _gwt_error "no command after '--' — usage: gwx [-d] [<branch>] -- <command>"; return 1; }

    local -a flags pos
    _gwt_split_args "${(@)pre}"
    _gwt_expand_short_flags            # future-proof: -da -> -d -a
    local detach="" all="" f
    for f in $flags; do
        case "$f" in
            -d|--detach) detach=1 ;;
            -a|--all)    all=1 ;;
            *) _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done
    (( ${#pos} <= 1 )) || { _gwt_error "unexpected argument before '--': ${pos[2]}"; return 1; }
    local branch="${pos[1]}"

    # -a: run in every worktree of this repo (a branch name would contradict "all").
    if [[ -n "$all" ]]; then
        [[ -z "$branch" ]] || { _gwt_error "-a runs in all worktrees — drop the branch name"; return 1; }
        _gwt_exec_all "$detach" "${cmd[@]}"
        return $?
    fi

    local wt
    if [[ -n "$branch" ]]; then
        wt="$(_gwt_worktree_for_branch "$branch")"
        [[ -n "$wt" ]] || { _gwt_error "no worktree for branch '$branch'"; return 1; }
    elif _gwt_is_picker_available; then
        wt="$(_gwt_pick -p 'exec')" || {
            [[ $? == 130 ]] && print -z -- "gwx${pre:+ ${(j: :)${(q)pre}}} -- ${(j: :)${(q)cmd}} "   # ESC → restore the line
            return 0
        }
        [[ -n "$wt" ]] || return 0
    else
        _gwt_error "usage: gwx [-d] <branch> -- <command>   (no fzf: name a branch)"
        return 1
    fi
    [[ -d "$wt" ]] || { _gwt_error "no worktree at $wt"; return 1; }

    # Attached: subshell keeps the caller's cwd/TTY put; the exit code propagates.
    if [[ -z "$detach" ]]; then
        ( cd -q "$wt" && "${cmd[@]}" )
        return $?
    fi

    # Detached: `&!` = background + disown (survives the terminal); log stdout+stderr.
    local REPLY; _gwt_repo_dir || return 1                 # REPLY = $GWT_WORKTREE_DIR/<repo>
    local logdir="$GWT_EXEC_LOG_DIR/${REPLY:t}"
    mkdir -p "$logdir" || { _gwt_error "could not create log dir: $logdir"; return 1; }
    local log="$logdir/${wt:t}.log"
    setopt local_options no_monitor
    ( cd -q "$wt" && "${cmd[@]}" ) >| "$log" 2>&1 &!
    _gwt_info "gwx: '${cmd[1]}' running in background (pid $!) in ${wt:t}"
    _gwt_info "     log: $log   —   tail -f to watch"
}

# Run <cmd…> in every worktree of the current repo.
# $1 = detach flag ("" = attached, non-empty = -da); the rest is the command.
#   Attached: run all in parallel (output captured), then print a labeled block per
#   worktree + a summary; continue on error; non-zero if any failed.
#   Detached (-da): launch a disowned background job per worktree, each to its own log.
function _gwt_exec_all() {
    local detach="$1"; shift
    local -a cmd=("$@")

    local -a reply; _gwt_worktrees
    local -a wts; local row
    for row in $reply; do wts+=("${row%%$'\t'*}"); done
    (( ${#wts} )) || { _gwt_error "no worktrees in this repo"; return 1; }

    local REPLY; _gwt_repo_dir || return 1
    local logbase="$GWT_EXEC_LOG_DIR/${REPLY:t}"
    setopt local_options no_monitor

    if [[ -n "$detach" ]]; then
        mkdir -p "$logbase" || { _gwt_error "could not create log dir: $logbase"; return 1; }
        local wt log
        for wt in $wts; do
            log="$logbase/${wt:t}.log"
            ( cd -q "$wt" && "${cmd[@]}" ) >| "$log" 2>&1 &!
            _gwt_info "gwx: launched ${wt:t} (pid $! · log $log)"
        done
        return 0
    fi

    local tmpd; tmpd="$(mktemp -d "${TMPDIR:-/tmp}/gwx.XXXXXX")" || { _gwt_error "could not create a temp dir"; return 1; }
    local -a pids
    local i
    for (( i = 1; i <= ${#wts}; i++ )); do
        ( cd -q "${wts[$i]}" && "${cmd[@]}" ) >"$tmpd/$i.out" 2>&1 &
        pids+=($!)
    done
    local -a rcs
    for (( i = 1; i <= ${#pids}; i++ )); do wait ${pids[$i]}; rcs[$i]=$?; done

    local ok=0 failed=0 rc wt line
    local -a failed_names
    for (( i = 1; i <= ${#wts}; i++ )); do
        wt="${wts[$i]}"; rc=${rcs[$i]}
        (( i > 1 )) && _gwt_info ""
        _gwt_info "▶ ${wt:t}"
        while IFS= read -r line || [[ -n "$line" ]]; do _gwt_info "  $line"; done < "$tmpd/$i.out"
        if (( rc == 0 )); then _gwt_info "  ✓ exit 0"; (( ok++ ))
        else                   _gwt_info "  ✗ exit $rc"; (( failed++ )); failed_names+=("${wt:t}"); fi
    done
    rm -rf "$tmpd"

    _gwt_info ""
    _gwt_info "gwx -a: ${#wts} worktree(s) · ${ok} ok · ${failed} failed${failed_names:+ (${(j:, :)failed_names})}"
    return $(( failed ? 1 : 0 ))
}

# Remove the worktree gwa created for <branch>.
# With no <branch>: fzf multi-picker if available (mark several, remove all).
# gwr [-d | -D] [<branch>] [git-worktree-remove flags, e.g. --force]
#   -d : also delete the branch (safe: refuses if it has unmerged commits)
#   -D : also delete the branch (force: even if unmerged)
function gwr() {
    _gwt_require_repo || return 1
    local -a flags pos passthru
    local delete_flag=""             # "" | -d (safe) | -D (force), mirrors git branch
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -d|-D) delete_flag="$f" ;;
            *)     passthru+=("$f") ;;   # e.g. --force -> git worktree remove
        esac
    done

    # Target worktree path(s): an explicit <branch>, else the interactive picker.
    local -a targets
    local wt wt_branch unique rc=0
    if [[ -n "${pos[1]}" ]]; then
        wt="$(_gwt_worktree_for_branch "${pos[1]}")"     # real path from git worktree list
        [[ -n "$wt" ]] || { _gwt_error "no worktree for branch '${pos[1]}'"; return 1; }
        targets=("$wt")
    elif _gwt_is_picker_available; then
        targets=("${(@f)$(_gwt_pick -m --skip-current -p 'remove')}") || { [[ $? == 130 ]] && print -z -- "${0}${flags:+ $flags} "; return 0; }   # ESC -> reinject cmd
        (( ${#targets} )) || return 0            # nothing selected -> no-op
    else
        _gwt_error "usage: [-d|-D] <branch> [--force]"
        return 1
    fi

    local label
    for wt in $targets; do
        label="${wt:t}"
        # Capture the branch checked out before removing it, so a -d/-D delete
        # targets the right ref even when <branch> was given in flattened form.
        wt_branch=""
        [[ -n "$delete_flag" ]] && wt_branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)"

        # removes worktree fast via _gwt_remove_one, real uncommitted work makes git refuse & warn.
        if (( ${#passthru} )); then
            git worktree remove "$wt" "${passthru[@]}" || { rc=1; continue; }
        elif _gwt_worktree_is_clean "$wt"; then
            _gwt_remove_one "$wt" "$label" || { rc=1; continue; }
        else
            git worktree remove "$wt" || { rc=1; continue; }
        fi

        if [[ -n "$delete_flag" && -n "$wt_branch" && "$wt_branch" != HEAD ]]; then
            # Count commits unique to the branch before deleting (ref still exists).
            unique="$(git rev-list --count "HEAD..$wt_branch" 2>/dev/null)"
            if git branch "$delete_flag" "$wt_branch"; then
                git config --unset "branch.${wt_branch}.gwtBase" 2>/dev/null   # drop the origin stamp
                # Make the "why did it delete?" self-evident: an empty branch is safe.
                [[ "$unique" == 0 ]] && \
                    _gwt_info "branch '$wt_branch' had no unique commits — nothing was lost"
            fi
        fi
    done
    return $rc
}

# Remove "stale" worktrees: branch has no commits of its own beyond the default
# branch (merged or never diverged), or its remote branch is gone — then delete those
# branches. Dirty and default-branch worktrees are kept.
# gwclean [-n]
#   -n | --dry-run: preview what would be removed, without removing anything
function gwclean() {
    _gwt_require_repo || return 1
    local -a flags pos
    local dry=""
    _gwt_split_args "$@"
    local f
    for f in $flags; do
        case "$f" in
            -n|--dry-run) dry=1 ;;
            *) _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done

    local repo_dir REPLY
    _gwt_repo_dir || return 1
    repo_dir="$REPLY"

    local -a wts=(${repo_dir}/*(/N))
    (( ${#wts} )) || { _gwt_info "gwclean: no worktrees under $repo_dir"; return 0; }

    # Refresh remotes so "gone upstream" is accurate — can be slow, so show a spinner.
    setopt local_options no_monitor
    local ftmp; ftmp="$(mktemp "${TMPDIR:-/tmp}/gwt-fetch.XXXXXX")"
    git fetch --prune --quiet origin >"$ftmp" 2>&1 &
    _gwt_spin $! "checking remotes…"
    rm -f "$ftmp"

    local default_branch
    default_branch="${$(_gwt_default_branch)#origin/}"

    local wt_dir branch item n_removed=0
    local -a would skipped
    for wt_dir in $wts; do
        branch="$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
        [[ -z "$branch" || "$branch" == HEAD || "$branch" == (main|master) || "$branch" == "$default_branch" ]] && continue
        _gwt_branch_stale "$branch" || continue
        if ! _gwt_worktree_is_clean "$wt_dir"; then
            skipped+=("${wt_dir:t} ($branch) — uncommitted changes")
            continue
        fi
        if [[ -n "$dry" ]]; then
            would+=("${wt_dir:t} ($branch)")                        # would remove; don't touch anything
        elif _gwt_remove_one "$wt_dir" "${wt_dir:t}"; then          # spinner -> "✓ removed <name>"
            git branch -D "$branch" >/dev/null 2>&1
            git config --unset "branch.${branch}.gwtBase" 2>/dev/null   # drop the origin stamp
            (( n_removed++ ))
        else
            skipped+=("${wt_dir:t} ($branch) — remove failed")
        fi
    done

    if [[ -n "$dry" ]]; then
        if (( ${#would} )); then
            _gwt_info "gwclean: would remove ${#would} worktree(s):"
            for item in $would; do _gwt_info "  $item"; done
        else
            _gwt_info "gwclean: nothing to clean"
        fi
    else
        (( n_removed == 0 && ${#skipped} == 0 )) && _gwt_info "gwclean: nothing to clean"
        if (( ${#skipped} )); then
            _gwt_info "gwclean: skipped ${#skipped}:"
            for item in $skipped; do _gwt_info "  $item"; done
        fi
        (( n_removed || ${#skipped} )) && _gwt_info "gwclean: removed ${n_removed}, skipped ${#skipped}"
    fi
    [[ -n "$dry" ]] && (( ${#would} ))
}

# ---------------------------------------------------------------------------
# Core & git helpers
# ---------------------------------------------------------------------------

# Sets REPLY to $GWT_WORKTREE_DIR/<repo-name> for the current repo.
function _gwt_repo_dir() {
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || {
        _gwt_error "current directory is not inside a git repository"
        return 1
    }
    common="${common:A}"                     # -> /abs/path/repo/.git
    REPLY="$GWT_WORKTREE_DIR/${common:h:t}"   # -> $GWT_WORKTREE_DIR/repo
}

# Fail with a clean, uniform message when not inside a git repository.
# Called at the top of every worktree-acting command so the error is consistent
# (never a raw "fatal: not a git repository"). gwl -a is exempt (scans GWT_WORKTREE_DIR).
function _gwt_require_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 && return 0
    _gwt_error "not inside a git repository"
    return 1
}

# Split argv into caller-local arrays `flags` (tokens starting with -) and
# `pos` (the rest). Caller must declare: local -a flags pos
function _gwt_split_args() {
    flags=(); pos=()
    local a
    for a in "$@"; do
        case "$a" in
            -*) flags+=("$a") ;;
            *)  pos+=("$a") ;;
        esac
    done
}

# Expand bundled short flags in the caller-local `flags` array: -abp -> -a -b -p.
# Long flags (--all) and single shorts (-a) pass through untouched.
function _gwt_expand_short_flags() {
    local -a out; local f i
    for f in $flags; do
        case "$f" in
            --*) out+=("$f") ;;                                      # long flag: keep whole
            -?*) for (( i = 2; i <= $#f; i++ )); do out+=("-${f[i]}"); done ;;   # -abp -> -a -b -p
            *)   out+=("$f") ;;                                      # anything else: keep
        esac
    done
    flags=("${out[@]}")
}

# Sets REPLY to the worktree path for <branch>: $GWT_WORKTREE_DIR/<repo>/<branch>.
function _gwt_wt_path() {
    _gwt_repo_dir || return 1                # REPLY = repo dir
    REPLY="$REPLY/${1//\//-}"
}

# Sets `reply` to one "path<TAB>branch" row per worktree. $1 = optional repo dir
# (default: cwd). branch is "(detached)" for a detached HEAD. Caller: local -a reply
function _gwt_worktrees() {
    local -a C; [[ -n "$1" ]] && C=(-C "$1")
    reply=()
    local line cpath="" cbranch=""
    for line in "${(@f)$(git $C worktree list --porcelain 2>/dev/null)}"; do
        case "$line" in
            "worktree "*)
                [[ -n "$cpath" ]] && reply+=("$cpath"$'\t'"$cbranch")
                cpath="${line#worktree }"; cbranch="(detached)" ;;
            "branch refs/heads/"*) cbranch="${line#branch refs/heads/}" ;;
        esac
    done
    [[ -n "$cpath" ]] && reply+=("$cpath"$'\t'"$cbranch")
}

# Print the path of the worktree that has <branch> checked out, if any.
function _gwt_worktree_for_branch() {
    local -a reply; local row
    _gwt_worktrees
    for row in $reply; do
        [[ "${row#*$'\t'}" == "$1" ]] && { print -r -- "${row%%$'\t'*}"; return 0; }
    done
    return 1
}

# Create the worktree for <branch> at $GWT_WORKTREE_DIR/<repo>/<branch>. Assumes the
# branch has no worktree yet. $1 = branch, $2 = optional start-point for a NEW branch (defaults to HEAD).
# Sets reply=(<worktree-path> <base>), where <base> is the branch a NEW branch was cut 
# from — empty when adopting an existing local/origin branch (git's own output already reports those).
function _gwt_create_worktree() {
    local branch="$1" startpoint="$2" wt base="" REPLY
    _gwt_wt_path "$branch" || return 1
    wt="$REPLY"
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$wt" "$branch" >/dev/null || return 1
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        _gwt_note "'$branch' already exists on origin — creating from origin/$branch, not HEAD"
        git worktree add --track -b "$branch" "$wt" "origin/$branch" >/dev/null || return 1
    else
        local sp="${startpoint:-HEAD}"
        git worktree add -b "$branch" "$wt" "$sp" >/dev/null || return 1
        # Resolve a bare HEAD to the current branch name (short SHA if detached).
        [[ "$sp" == HEAD ]] && sp="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
        base="$sp"
    fi
    reply=("$wt" "$base")
}

# Seed a new worktree with the gitignored files this repo needs: copy each present
# $GWT_COPY_FILES entry from <src-worktree> ($1) into <dst-worktree> ($2). Worktrees
# don't inherit gitignored files, so anything untracked (e.g. .env) must be copied.
function _gwt_seed_files() {
    local src="$1" dst="$2" f
    for f in $GWT_COPY_FILES; do
        [[ -f "$src/$f" ]] || continue
        mkdir -p "$dst/${f:h}"
        cp "$src/$f" "$dst/$f"
    done
}

# ---------------------------------------------------------------------------
# Editor & clipboard
# ---------------------------------------------------------------------------

# Expand $GWT_OPEN_CMD for path <$1>: substitute {} (or append if absent).
# <$2> = quoting style for the path: 'q' shell-quotes it (safe for eval),
# anything else wraps it in plain double quotes (readable, for clipboard).
function _gwt_open_cmd() {
    local ph='{}' p
    [[ "$2" == q ]] && p="${(q)1}" || p="\"$1\""
    if [[ "$GWT_OPEN_CMD" == *"$ph"* ]]; then
        print -r -- "${GWT_OPEN_CMD//$ph/$p}"
    else
        print -r -- "$GWT_OPEN_CMD $p"
    fi
}

# Copy a ready-to-run "open" command to the clipboard.
function _gwt_copy() {
    local clip="${GWT_CLIPBOARD_CMD%% *}"    # first word = the binary to probe
    [[ -n "$clip" ]] && command -v "$clip" >/dev/null || return 0
    _gwt_open_cmd "$1" | eval "$GWT_CLIPBOARD_CMD"
}

# Open the worktree at <path>.
function _gwt_open() {
    eval "$(_gwt_open_cmd "$1" q)"
}

# ---------------------------------------------------------------------------
# Git & branch helpers
# ---------------------------------------------------------------------------

# True if the worktree at <path> has no real changes.
function _gwt_worktree_is_clean() {
    local line p
    for line in "${(@f)$(git -C "$1" status --porcelain -uall 2>/dev/null)}"; do
        [[ -z "$line" ]] && continue
        p="${line[4,-1]}"                          # strip the "XY " status prefix
        (( ${GWT_COPY_FILES[(Ie)$p]} )) && continue
        return 1                                   # a real change -> not clean
    done
    return 0
}

# Remove one worktree at <path> (labeled <label> in messages), with an in-place
# spinner that resolves to "✓ removed <label>" on the same line.
function _gwt_remove_one() {
    local wt="$1" label="$2" tmp rc bin="${GWT_TRASH_CMD%% *}" via_trash=""
    [[ -n "$bin" ]] && command -v "$bin" >/dev/null && via_trash=1

    setopt local_options no_monitor
    tmp="$(mktemp "${TMPDIR:-/tmp}/gwt-rm.XXXXXX")" || { _gwt_error "could not create a temp file"; return 1; }

    if [[ -n "$via_trash" ]]; then
        { eval "$GWT_TRASH_CMD ${(q)wt}" && git worktree prune; } >"$tmp" 2>&1 &
        _gwt_spin $! "removing ${label}…"; rc=$?
        if (( rc )); then                       # trash failed -> fall back to native
            _gwt_warn "trash failed — removing directly"
            : >"$tmp"
            git worktree remove --force "$wt" >"$tmp" 2>&1 &
            _gwt_spin $! "removing ${label}…"; rc=$?
        fi
    else
        git worktree remove --force "$wt" >"$tmp" 2>&1 &
        _gwt_spin $! "removing ${label}…"; rc=$?
    fi

    if (( rc )); then
        cat "$tmp" >&2
    else
        _gwt_info "✓ removed ${label}"
    fi
    rm -f "$tmp"
    return $rc
}

# Print the repo's default branch as a remote ref, e.g. "origin/main".
# Prefers the remote's advertised HEAD (set at clone time); else guesses.
# $1 = optional repo dir to run against (default: cwd).
function _gwt_default_branch() {
    local -a C; [[ -n "$1" ]] && C=(-C "$1")
    local ref b
    ref="$(git $C symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" \
        && { print -r -- "$ref"; return 0; }
    for b in main master trunk develop; do
        if git $C show-ref --verify --quiet "refs/remotes/origin/$b"; then
            print -r -- "origin/$b"; return 0
        fi
    done
    return 1
}

# "Stale" = branch has no commits of its own beyond the default branch (merged or
# never diverged), or its upstream is gone. True for such branches — safe to remove.
# $1 = branch, $2 = optional repo dir to run against (default: cwd).
function _gwt_branch_stale() {
    local -a C; [[ -n "$2" ]] && C=(-C "$2")
    local base; base="$(_gwt_default_branch "$2")"
    [[ -n "$base" ]] && git $C merge-base --is-ancestor "refs/heads/$1" "$base" 2>/dev/null && return 0
    [[ "$(git $C for-each-ref --format='%(upstream:track)' "refs/heads/$1" 2>/dev/null)" == *gone* ]]
}

# ---------------------------------------------------------------------------
# Tab completion
# ---------------------------------------------------------------------------

# complete short branch names — local + remote (origin/ stripped), deduped.
# Short names are what gwa expects; 'origin/x' would make a bogus local branch.
function _gwt_complete_branches() {
    local -aU names   # -U dedupes local vs remote of the same name
    names=(
        ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)"}
        ${(f)"$(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes 2>/dev/null)"}
    )
    compadd -- ${names:#HEAD}
}

# gwo / gws / gwr: complete branches that currently have a worktree.
# gwr drops the primary worktree — git refuses to remove the main working tree.
function _gwt_complete_worktrees() {
    local -a reply; local row b
    _gwt_worktrees 2>/dev/null            # reply = "path<TAB>branch" rows, primary first
    local -a branches
    local i=0
    for row in $reply; do
        (( i++ ))
        [[ "$words[1]" == gwr ]] && (( i == 1 )) && continue   # skip primary for gwr
        b="${row#*$'\t'}"
        [[ "$b" == "(detached)" ]] && continue
        branches+=("$b")
    done
    compadd -- $branches
}

# gwx: worktree branches before `--`; after `--`, defer to normal command completion.
function _gwt_complete_gwx() {
    local i
    for (( i = 2; i < CURRENT; i++ )); do
        [[ "${words[i]}" == "--" ]] && { _normal; return; }
    done
    _gwt_complete_worktrees
}

(( $+functions[compdef] )) && {
    compdef _gwt_complete_branches gwa
    compdef _gwt_complete_worktrees gwo gws gwr
    compdef _gwt_complete_gwx gwx
}

# ---------------------------------------------------------------------------
# Worktree status dashboard.
#
# Columns:
#   marker       ▶ current worktree · ⌂ main worktree
#   branch       branch checked out in the worktree
#   state        dirty / clean  (any uncommitted changes?)
#   sync         vs upstream: ↑ahead ↓behind · synced · gone · local
#   last commit  subject + how long ago
#
# Rows are sorted newest-commit-first.
# ⚑ stale marks branches gwclean would remove (merged, never diverged, or gone).
#
# Usage: gwl [-a | --all] [-p | --paths] [-b | --base]     (short flags bundle: -abp)
#   -a   show every repo under $GWT_WORKTREE_DIR (works from any directory)
#   -p   also show each worktree's path + short SHA
#   -b   show what each NEW branch was cut from (the durable origin stamp; — if none)
# ---------------------------------------------------------------------------

# Print one repository's worktrees as dashboard rows (helper for gwl).
function _gwt_gather_repo() {
    local label="$1" repo_dir="$2"
    local base default_branch
    base="$(_gwt_default_branch "$repo_dir")"        # computed ONCE per repo (not per worktree)
    default_branch="${base#origin/}"

    # Collect (path, branch) for every worktree of this repo; main is listed first.
    local -a wt_paths wt_branches reply
    local wt_row
    _gwt_worktrees "$repo_dir"
    for wt_row in $reply; do
        wt_paths+=("${wt_row%%$'\t'*}"); wt_branches+=("${wt_row#*$'\t'}")
    done
    (( ${#wt_paths} )) || return 0

    # ONE bulk query for per-branch metadata: date, "when", upstream, track, subject
    # (\x1f field separator; parsed with %%/# to preserve empty fields).
    local SEP=$'\x1f'
    local -A m_ts m_when m_up m_track m_subj m_sha
    local rec b
    local fmt="%(refname:short)${SEP}%(committerdate:unix)${SEP}%(committerdate:relative)${SEP}%(upstream:short)${SEP}%(upstream:track)${SEP}%(contents:subject)${SEP}%(objectname:short)"
    for rec in "${(@f)$(git -C "$repo_dir" for-each-ref --format=$fmt refs/heads 2>/dev/null)}"; do
        b="${rec%%${SEP}*}";        rec="${rec#*${SEP}}"
        m_ts[$b]="${rec%%${SEP}*}";    rec="${rec#*${SEP}}"
        m_when[$b]="${rec%%${SEP}*}";  rec="${rec#*${SEP}}"
        m_up[$b]="${rec%%${SEP}*}";    rec="${rec#*${SEP}}"
        m_track[$b]="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        m_subj[$b]="${rec%%${SEP}*}";  rec="${rec#*${SEP}}"
        m_sha[$b]="$rec"
    done

    # ONE bulk query for the "merged into default" set (replaces per-branch merge-base).
    local -A merged
    if [[ -n "$base" ]]; then
        for b in "${(@f)$(git -C "$repo_dir" branch --merged "$base" --format='%(refname:short)' 2>/dev/null)}"; do
            [[ -n "$b" ]] && merged[$b]=1
        done
    fi

    # Durable branch-origin stamps (only when the BASE column is requested).
    local -A m_base
    if [[ -n "$show_base" ]]; then
        local cfgline cfgname
        for cfgline in "${(@f)$(git -C "$repo_dir" config --get-regexp '^branch\..*\.gwtbase$' 2>/dev/null)}"; do
            [[ -z "$cfgline" ]] && continue
            cfgname="${${cfgline%% *}#branch.}"; cfgname="${cfgname%.gwtbase}"
            m_base[$cfgname]="${cfgline#* }"
        done
    fi

    local -a group dirty_flag pids
    local i d branch ts when subject up track ahead behind mark stale is_cur state sync sync_color
    local info restd branch_trunc subject_trunc branch_cell state_cell sync_cell subject_cell row tmpd
    local sha when_out path_info base_info

    # The dirty check is the one per-worktree working-tree scan. The scans are
    # independent, so run them in parallel and collect the results — wall-time is
    # ~the slowest single scan instead of the sum. (no_monitor: no job-control spam.)
    setopt local_options no_monitor
    tmpd="$(mktemp -d "${TMPDIR:-/tmp}/gwl.XXXXXX")"
    for (( i = 1; i <= ${#wt_paths}; i++ )); do
        d="${wt_paths[$i]}"
        { [[ -n "$(git -C "$d" --no-optional-locks status --porcelain 2>/dev/null)" ]] \
            && print dirty || print clean } > "$tmpd/$i" &
        pids+=($!)
    done
    wait $pids
    for (( i = 1; i <= ${#wt_paths}; i++ )); do dirty_flag[$i]="$(< $tmpd/$i)"; done
    rm -rf "$tmpd"

    for (( i = 1; i <= ${#wt_paths}; i++ )); do
        d="${wt_paths[$i]}"; branch="${wt_branches[$i]}"
        (( n_total++ ))

        # metadata from the bulk query; detached HEADs aren't in refs/heads -> fall back
        if [[ "$branch" == "(detached)" ]]; then
            info="$(git -C "$d" log -1 --format='%ct%x1f%cr%x1f%s%x1f%h' 2>/dev/null)"
            ts="${info%%$'\x1f'*}"; restd="${info#*$'\x1f'}"
            when="${restd%%$'\x1f'*}"; restd="${restd#*$'\x1f'}"
            subject="${restd%%$'\x1f'*}"; sha="${restd#*$'\x1f'}"
            [[ -n "$ts" ]] || ts=0; [[ -n "$when" ]] || when="-"; [[ -n "$subject" ]] || subject="-"
            sync="-"; sync_color="$C_DIM"
        else
            ts="${m_ts[$branch]:-0}"; when="${m_when[$branch]:--}"; subject="${m_subj[$branch]:--}"
            sha="${m_sha[$branch]}"
            up="${m_up[$branch]}"; track="${m_track[$branch]}"
            if   [[ "$track" == *gone* ]]; then sync="gone";   sync_color="$C_GONE"
            elif [[ -z "$up" ]];           then sync="local";  sync_color="$C_DIM"
            elif [[ -z "$track" ]];        then sync="synced"; sync_color="$C_OK"
            else
                ahead=0; behind=0
                [[ "$track" == *"ahead "* ]]  && { ahead="${track#*ahead }";   ahead="${ahead%%[^0-9]*}"; }
                [[ "$track" == *"behind "* ]] && { behind="${track#*behind }"; behind="${behind%%[^0-9]*}"; }
                sync="↑${ahead:-0} ↓${behind:-0}"
                if   (( ${ahead:-0} > 0 && ${behind:-0} > 0 )); then sync_color="$C_DIVERGE"
                elif (( ${ahead:-0} > 0 ));                      then sync_color="$C_OK"
                else                                                 sync_color="$C_WARN"; fi
            fi
        fi

        # dirty state was computed in parallel above
        if [[ "${dirty_flag[$i]}" == dirty ]]; then
            state="dirty"; (( n_dirty++ ))
        else
            state="clean"
        fi

        # stale = merged into default (bulk set) OR upstream gone; same guards as gwclean
        stale=""
        if [[ "$branch" != "(detached)" && "$branch" != "$default_branch" && "$branch" != (main|master) ]] \
           && { [[ -n "${merged[$branch]}" ]] || [[ "$sync" == gone ]]; }; then
            stale=1; (( n_stale++ ))
            [[ "$state" == clean ]] && (( n_removable++ ))
        fi

        # marker: current worktree > main worktree > none
        if [[ -n "$here" && "$d" == "$here" ]]; then mark="▶"
        elif (( i == 1 ));                        then mark="⌂"
        else                                           mark=" "; fi

        # pad on plain text, then wrap in color -> columns stay aligned
        branch_trunc="${branch[1,20]}";   branch_cell="${(r:20:)branch_trunc}"
        subject_trunc="${subject[1,30]}"; subject_cell="${(r:30:)subject_trunc}"
        state_cell="${(r:6:)state}";      sync_cell="${(r:11:)sync}"
        is_cur=""; [[ -n "$here" && "$d" == "$here" ]] && is_cur=1

        # Pad WHEN once BASE or PATH follows it; BASE (padded) sits between WHEN and the ragged PATH.
        when_out="$when"; path_info=""; base_info=""
        [[ -n "$show_paths" || -n "$show_base" ]] && when_out="${(r:16:)when}"
        [[ -n "$show_base"  ]] && base_info="  ${(r:20:)${m_base[$branch]:-—}}"
        [[ -n "$show_paths" ]] && path_info=" ${(r:7:)sha}  ${d}"

        if [[ -n "$stale" ]]; then
            # stale rows recede: render plain, then dim the whole line
            row="${C_DIM}$mark ${branch_cell}   ${state_cell} ${sync_cell} ${subject_cell}    ${when_out}${base_info}${path_info}  ⚑ stale${C_RESET}"
        else
            [[ "$mark" == "▶" ]] && mark="${C_CUR}▶${C_RESET}"
            [[ "$mark" == "⌂" ]] && mark="${C_MAIN}⌂${C_RESET}"
            [[ -n "$is_cur" ]] && branch_cell="${C_CUR}${branch_cell}${C_RESET}"          # current branch pops
            if [[ "$state" == dirty ]]; then state_cell="${C_DIRTY}${state_cell}${C_RESET}"
            else                             state_cell="${C_DIM}${state_cell}${C_RESET}"; fi   # clean/unknown recedes
            sync_cell="${sync_color}${sync_cell}${C_RESET}"
            row="$mark ${branch_cell}   ${state_cell} ${sync_cell} ${subject_cell}    ${when_out}${base_info}${path_info}"
        fi
        group+=("${ts}"$'\t'"$row")
    done

    group=("${(@On)group}")                       # newest commit first
    (( n_shown++ ))
    (( n_shown > 1 )) && _gwt_info ""               # blank line between repo groups
    [[ -n "$label" ]] && _gwt_info "${C_BOLD}${label}${C_RESET}"
    local r
    for r in $group; do _gwt_info "${r#*$'\t'}"; done
}

function gwl() {
    local -a flags pos
    local all="" show_paths="" show_base="" REPLY
    _gwt_split_args "$@"
    _gwt_expand_short_flags            # allow bundled shorts: gwl -abp == -a -b -p
    local f
    for f in $flags; do
        case "$f" in
            -a|--all)   all=1 ;;
            -p|--paths) show_paths=1 ;;
            -b|--base)  show_base=1 ;;
            *) _gwt_error "unknown flag: $f"; return 1 ;;
        esac
    done

    # Color codes — only on a real terminal (this fd, not a subshell) & no NO_COLOR.
    local C_RESET="" C_DIM="" C_BOLD="" C_CUR="" C_MAIN="" C_DIRTY="" C_OK="" C_WARN="" C_DIVERGE="" C_GONE=""
    if [[ -t 1 && -z "$NO_COLOR" ]]; then
        C_RESET=$'\e[0m'; C_DIM=$'\e[2m'; C_BOLD=$'\e[1m'
        C_CUR=$'\e[1;36m'    # bold cyan — current worktree
        C_MAIN=$'\e[34m'     # blue      — main worktree
        C_DIRTY=$'\e[33m'    # yellow    — uncommitted changes
        C_OK=$'\e[32m'       # green     — synced / ahead
        C_WARN=$'\e[33m'     # yellow    — behind
        C_DIVERGE=$'\e[35m'  # magenta   — diverged (ahead & behind)
        C_GONE=$'\e[31m'     # red       — upstream gone
    fi

    local here; here="$(git rev-parse --show-toplevel 2>/dev/null)"
    local n_total=0 n_dirty=0 n_stale=0 n_removable=0 n_repos=0 n_shown=0

    local h1=BRANCH h2=STATE h3=SYNC h4="LAST COMMIT" h5=WHEN h6=COMMIT h7=BASE
    # WHEN is padded once BASE or PATH follows it; BASE sits between WHEN and PATH so both align.
    local when_h="$h5" base_h="" path_h=""
    [[ -n "$show_paths" || -n "$show_base" ]] && when_h="${(r:16:)h5}"
    [[ -n "$show_base"  ]] && base_h="  ${(r:20:)h7}"
    [[ -n "$show_paths" ]] && path_h=" ${(r:7:)h6}  PATH"
    local header="${C_BOLD}  ${(r:20:)h1}   ${(r:6:)h2} ${(r:11:)h3} ${(r:30:)h4}    ${when_h}${base_h}${path_h}${C_RESET}"

    if [[ -n "$all" ]]; then
        # every repo under $GWT_WORKTREE_DIR — works from anywhere, no repo needed
        local -a repodirs=(${GWT_WORKTREE_DIR}/*(/N))
        (( ${#repodirs} )) || { _gwt_info "gwl: no worktrees under $GWT_WORKTREE_DIR"; return 0; }
        _gwt_info "$header"
        local repodir
        local -a wtsub
        for repodir in $repodirs; do
            wtsub=(${repodir}/*(/N))
            (( ${#wtsub} )) || continue
            (( n_repos++ ))
            _gwt_gather_repo "${repodir:t}" "${wtsub[1]}"
        done
    else
        _gwt_require_repo || return 1
        _gwt_repo_dir || return 1
        _gwt_info "$header"
        _gwt_gather_repo "" "$PWD"
        n_repos=1
    fi

    local summary="${n_total} worktree(s)"
    [[ -n "$all" ]] && summary+=" across ${n_repos} repo(s)"
    summary+=" · ${n_dirty} dirty · ${n_stale} stale"
    (( n_removable )) && summary+=" (gwclean would remove ${n_removable})"
    _gwt_info ""
    _gwt_info "${C_DIM}${summary}${C_RESET}"
}

# ---------------------------------------------------------------------------
# Logging — info to stdout; note/warn/error to stderr
# ---------------------------------------------------------------------------

function _gwt_info()  { print -r -- "$*"; }          # normal output, stdout, plain
function _gwt_note()  { _gwt_emit '38;5;208' "$*"; }  # heads-up (orange)
function _gwt_warn()  { _gwt_emit '33'        "$*"; } # warning  (yellow)
function _gwt_error() { _gwt_emit '31'        "$*"; } # failure  (red)

# _gwt_emit <ansi-code> <msg>: print "<cmd>: <msg>" to stderr, colored on a TTY.
function _gwt_emit() {
    local msg="$(_gwt_cmd): $2"
    [[ -t 2 && -z "$NO_COLOR" ]] && msg=$'\e['"$1"'m'"$msg"$'\e[0m'
    print -r -- "$msg" >&2
}

# The public gw command that triggered the message: first non-internal frame.
function _gwt_cmd() {
    local f
    for f in $funcstack; do
        [[ $f == _gwt_* ]] && continue
        print -r -- "$f"; return
    done
    print -r -- gw
}

# ---------------------------------------------------------------------------
# Interactive picker (fzf) — optional; used only when fzf is installed
# ---------------------------------------------------------------------------

# Interactively pick worktree(s) of the current repo.
# Returns non-zero if (ESC/^C) or nothing is selected
# _gwt_pick [-m] [--skip-current] [-p <prompt>]
#   -m              multi-select (prints one path per line)
#   --skip-current  omit the worktree you're standing in (used by gwr)
#   -p <prompt>     fzf prompt label
function _gwt_pick() {
    local multi="" skip_current="" prompt="pick"
    while (( $# )); do
        case "$1" in
            -m)             multi=1 ;;
            --skip-current) skip_current=1 ;;
            -p)             prompt="$2"; shift ;;
        esac
        shift
    done

    _gwt_repo_dir || return 1

    # (path, branch) for every worktree of this repo.
    local -a wt_paths wt_branches reply
    local line row
    _gwt_worktrees
    for row in $reply; do
        wt_paths+=("${row%%$'\t'*}"); wt_branches+=("${row#*$'\t'}")
    done

    local here=""
    [[ -n "$skip_current" ]] && here="$(git rev-parse --show-toplevel 2>/dev/null)"

    # one bulk query for commit times -> newest-first ordering (matches gwl)
    local -A m_ts
    local rec
    for rec in "${(@f)$(git for-each-ref --format='%(refname:short) %(committerdate:unix)' refs/heads 2>/dev/null)}"; do
        m_ts[${rec%% *}]="${rec##* }"
    done

    # build "ts \t branch \t path" rows, dropping the current worktree if asked
    local -a rows
    local i wt_path branch ts
    for (( i = 1; i <= ${#wt_paths}; i++ )); do
        wt_path="${wt_paths[$i]}"; branch="${wt_branches[$i]}"
        [[ -n "$here" && "$wt_path" == "$here" ]] && continue
        ts="${m_ts[$branch]:-0}"
        rows+=("${ts}"$'\t'"${branch}"$'\t'"${wt_path}")
    done
    (( ${#rows} )) || { _gwt_warn "no worktrees to pick"; return 1; }

    rows=("${(@On)rows}")                 # newest commit first
    local -a menu
    for line in $rows; do menu+=("${line#*$'\t'}"); done   # drop ts -> "branch \t path"

    local header='enter: select   ctrl-/: toggle preview'
    [[ -n "$multi" ]] && header='enter: confirm   tab: mark   ctrl-/: toggle preview'

    # fzf shows branch (field 1); path (field 2) rides along for preview + return.
    local sel
    sel="$(print -rl -- $menu | fzf --ansi \
        --delimiter=$'\t' --with-nth=1 \
        --height=40% --reverse --border \
        --prompt="$prompt> " \
        --header="$header" \
        --preview 'git -C {2} log --oneline --decorate -20 2>/dev/null; echo; echo "── status ──"; git -C {2} status -s 2>/dev/null' \
        --preview-window='right,50%,border-left' \
        --bind 'ctrl-/:toggle-preview' \
        ${=GWT_PICKER_OPTIONS} \
        ${multi:+--multi})"
    local rc=$?
    (( rc )) && return $rc                 # propagate fzf's code (130 = ESC/^C abort)
    [[ -n "$sel" ]] || return 1

    local sel_line
    for sel_line in "${(@f)sel}"; do print -r -- "${sel_line#*$'\t'}"; done   # emit path(s)
}

function _gwt_is_picker_available() { [[ -t 1 ]] && (( $+commands[fzf] )); }

# Interactively pick a branch that does NOT yet have a worktree; print its short
# name to stdout. Used by a bare `gwa` to create a worktree for an existing branch.
# Lists local heads + origin/* (deduped), newest-commit-first, with the relative
# date inline and author + recent commits in the preview. Returns non-zero on abort
# or when every branch already has a worktree.
function _gwt_pick_branch() {
    _gwt_repo_dir || return 1

    # Branches already checked out in some worktree -> exclude them.
    local -A has_wt
    local -a reply
    local line row branch
    _gwt_worktrees
    for row in $reply; do
        branch="${row#*$'\t'}"
        [[ "$branch" != "(detached)" ]] && has_wt[$branch]=1
    done

    local SEP=$'\x1f'
    local -A seen
    local -a rows                          # "ts \t display \t branch \t logref"
    local rec name ts rel_date display

    # local heads (logref = the branch itself)
    for rec in "${(@f)$(git for-each-ref --format="%(refname:short)${SEP}%(committerdate:unix)${SEP}%(committerdate:relative)" refs/heads 2>/dev/null)}"; do
        name="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        ts="${rec%%${SEP}*}"; rel_date="${rec#*${SEP}}"
        [[ -z "$name" || -n "${has_wt[$name]}" || -n "${seen[$name]}" ]] && continue
        seen[$name]=1
        display="${name[1,45]}"; display="${(r:45:)display}  ${rel_date}"
        rows+=("${ts}"$'\t'"${display}"$'\t'"${name}"$'\t'"${name}")
    done

    # origin branches without a local counterpart (logref = origin/<name>)
    for rec in "${(@f)$(git for-each-ref --format="%(refname:lstrip=3)${SEP}%(committerdate:unix)${SEP}%(committerdate:relative)" refs/remotes/origin 2>/dev/null)}"; do
        name="${rec%%${SEP}*}"; rec="${rec#*${SEP}}"
        ts="${rec%%${SEP}*}"; rel_date="${rec#*${SEP}}"
        [[ -z "$name" || "$name" == HEAD || -n "${has_wt[$name]}" || -n "${seen[$name]}" ]] && continue
        seen[$name]=1
        display="${name[1,45]}"; display="${(r:45:)display}  ${rel_date}"
        rows+=("${ts}"$'\t'"${display}"$'\t'"${name}"$'\t'"origin/${name}")
    done

    # No early return on an empty list: you can still type a NEW name to create it.
    rows=("${(@On)rows}")                  # newest commit first (no-op if empty)
    local -a menu
    for line in $rows; do menu+=("${line#*$'\t'}"); done   # drop ts -> "display \t branch \t logref"

    # --print-query makes fzf return what you TYPED (line 1) alongside what you
    # SELECTED (line 2+). Highlighted an existing branch -> adopt it; typed a name that
    # matched nothing -> create it as a new branch (gwa routes new-vs-existing itself).
    local out
    out="$(print -rl -- $menu | fzf --ansi \
        --print-query \
        --delimiter=$'\t' --with-nth=1 \
        --height=40% --reverse --border \
        --prompt='branch> ' \
        --header='enter: adopt highlighted · type a new name + enter: create it   ctrl-/: toggle preview' \
        --preview 'git log -1 --format="%an · %ar" {3} 2>/dev/null; echo; git log --oneline --decorate -20 {3} 2>/dev/null' \
        --preview-window='right,55%,border-left' \
        --bind 'ctrl-/:toggle-preview' \
        ${=GWT_PICKER_OPTIONS})"
    local rc=$?
    (( rc == 130 )) && return 130           # ESC/^C abort

    local query sel
    query="${out%%$'\n'*}"                   # line 1 = the typed query
    sel="${out#*$'\n'}"; [[ "$sel" == "$out" ]] && sel=""   # line 2+ = selection, if any

    if [[ -n "$sel" ]]; then
        local rest="${sel#*$'\t'}"           # drop display -> "branch \t logref"
        print -r -- "${rest%%$'\t'*}"        # adopt: emit the highlighted branch name
    elif [[ -n "$query" ]]; then
        print -r -- "$query"                 # create: emit the typed new branch name
    else
        return 1                              # nothing typed, nothing selected
    fi
}
