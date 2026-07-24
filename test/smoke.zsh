#!/usr/bin/env zsh
#
# Smoke test for gwt.
# Sources the plugin and exercises a real create → list → remove worktree
# lifecycle in a throwaway git repo. Pure zsh + git — no fzf, editor,
# clipboard, or trash tool required. Runs locally (`npm test`) and in CI.

ROOT=${0:A:h:h}
PLUGIN="$ROOT/src/gwt.zsh"

typeset -i pass=0 fail=0
_ok()  { print -r -- "  ✓ $1"; (( ++pass )); }
_bad() { print -r -- "  ✗ $1"; (( ++fail )); }

print -- "▶ loading $PLUGIN"

# Make compdef available so a source-time completion hook can't error out.
autoload -Uz compinit && compinit -u 2>/dev/null

err=$(mktemp)
if source "$PLUGIN" 2>"$err"; then
  _ok "sources without error"
else
  _bad "sources without error"
  cat "$err"
  exit 1
fi
rm -f "$err"

# --- public commands are defined (functions, or gwp which is an alias) ----
for fn in gwa gws gwo gwr gwl gwclean gwp gwt gwx; do
  (( $+functions[$fn] || $+aliases[$fn] )) && _ok "command $fn defined" || _bad "command $fn MISSING"
done

# --- version + help --------------------------------------------------------
ver=$(gwt -v 2>/dev/null)
[[ -n $ver ]] && _ok "gwt -v prints a version ($ver)" || _bad "gwt -v prints a version"

gwt -h 2>&1 | grep -qi 'gwa' && _ok "gwt -h lists commands" || _bad "gwt -h lists commands"

# --- real worktree lifecycle ----------------------------------------------
print -- "▶ worktree lifecycle"

tmp=$(mktemp -d)
GWT_WORKTREE_DIR="$tmp/wt"   # keep worktrees inside the throwaway dir
GWT_GWA_FETCH=0              # no origin in this repo
GWT_CLIPBOARD_CMD=''         # skip clipboard
GWT_TRASH_CMD=''             # force native git removal (deterministic)
GWT_COPY_FILES=()            # nothing to copy → clean worktree
GWT_OPEN_CMD='true {}'       # never actually open an editor

repo="$tmp/repo"
git init -q "$repo"
cd "$repo"
git config user.email test@example.com
git config user.name  "gwt smoke test"
git commit -q --allow-empty -m "init"

gwa smoke-branch </dev/null >/dev/null 2>&1

git show-ref --verify --quiet refs/heads/smoke-branch \
  && _ok "gwa created branch smoke-branch" || _bad "gwa created branch smoke-branch"

wt=$(git worktree list --porcelain \
       | awk '/^worktree /{p=$2} /^branch refs\/heads\/smoke-branch$/{print p}')
[[ -n $wt && -d $wt ]] && _ok "gwa created worktree dir" || _bad "gwa created worktree dir"

gwl </dev/null >/dev/null 2>&1 && _ok "gwl runs" || _bad "gwl runs"

# --- gwx: run a command inside the worktree (no cd) -----------------------
print -- "▶ gwx exec"

out=$(gwx smoke-branch -- pwd 2>/dev/null)
[[ "${out:A}" == "${wt:A}" ]] && _ok "gwx runs at the worktree root" || _bad "gwx runs at the worktree root (got: $out)"

gwx smoke-branch -- true  >/dev/null 2>&1 && _ok "gwx passes a zero exit code"     || _bad "gwx passes a zero exit code"
gwx smoke-branch -- false >/dev/null 2>&1;  (( $? != 0 )) && _ok "gwx passes a non-zero exit code" || _bad "gwx passes a non-zero exit code"

gwx smoke-branch pwd      >/dev/null 2>&1;  (( $? != 0 )) && _ok "gwx errors without --"          || _bad "gwx errors without --"
gwx no-such-branch -- pwd >/dev/null 2>&1;  (( $? != 0 )) && _ok "gwx errors on missing worktree" || _bad "gwx errors on missing worktree"

GWT_EXEC_LOG_DIR="$tmp/logs"
gwx -d smoke-branch -- sh -c 'echo BG_OK' >/dev/null 2>&1 && _ok "gwx -d launches" || _bad "gwx -d launches"
log="$tmp/logs/repo/smoke-branch.log"
found=""
for i in {1..40}; do [[ -f "$log" ]] && grep -q BG_OK "$log" && { found=1; break; }; sleep 0.05; done
[[ -n "$found" ]] && _ok "gwx -d wrote its log" || _bad "gwx -d wrote its log ($log)"

gwr smoke-branch </dev/null >/dev/null 2>&1
[[ -n $wt && ! -e $wt ]] && _ok "gwr removed worktree" || _bad "gwr removed worktree"

cd "$ROOT"
rm -rf "$tmp"

# --- summary ---------------------------------------------------------------
print -- ""
print -- "$pass passed, $fail failed"
(( fail == 0 ))
