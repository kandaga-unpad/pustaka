#!/bin/bash
# git_upstream.sh — Sync pustaka with upstream voile
# Run this from the pustaka repo root after finishing work in voile.
#
# Usage: bash scripts/git_upstream.sh
#
# What it does:
#   1. Ensures you are on main with a clean working tree
#   2. Fetches latest from upstream (voile)
#   3. Merges upstream/main — protected files auto-resolve to ours
#   4. If mix.exs conflicts, pauses so you can resolve it manually
#   5. Pushes the result to origin (pustaka)

set -e

UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"
ORIGIN_REMOTE="origin"
LOCAL_BRANCH="main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
section() { echo -e "\n${CYAN}==> $1${NC}"; }

# ── 0. Ensure we are in the repo root ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

section "Preflight checks"

# Ensure we are on the right branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$LOCAL_BRANCH" ]; then
  error "Expected branch '$LOCAL_BRANCH', currently on '$CURRENT_BRANCH'."
  error "Switch to main first: git checkout main"
  exit 1
fi
info "On branch: $LOCAL_BRANCH ✓"

# Ensure working tree is clean
if ! git diff --quiet || ! git diff --cached --quiet; then
  error "Working tree has uncommitted changes. Commit or stash them first."
  git status --short
  exit 1
fi
info "Working tree is clean ✓"

# Ensure upstream remote exists
if ! git remote get-url "$UPSTREAM_REMOTE" > /dev/null 2>&1; then
  error "Remote '$UPSTREAM_REMOTE' not found."
  error "Add it with: git remote add upstream git@github.com:curatorian/voile.git"
  exit 1
fi
info "Remote '$UPSTREAM_REMOTE' exists ✓"

# ── 1. Fetch upstream ────────────────────────────────────────────────────────
section "Fetching upstream (voile)"
git fetch "$UPSTREAM_REMOTE"
info "Fetched $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

# Show what's new upstream
NEW_COMMITS=$(git log --oneline "$LOCAL_BRANCH".."$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" | wc -l)
if [ "$NEW_COMMITS" -eq 0 ]; then
  info "Already up to date with upstream. Nothing to merge."
  exit 0
fi
info "$NEW_COMMITS new commit(s) in upstream:"
git log --oneline "$LOCAL_BRANCH".."$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

# ── 2. Merge upstream ────────────────────────────────────────────────────────
section "Merging $UPSTREAM_REMOTE/$UPSTREAM_BRANCH"

# Run merge — .gitattributes merge=ours handles protected files automatically
if git merge "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --no-edit; then
  info "Merge completed cleanly ✓"
else
  # Check if the only conflicts are in mix.exs
  CONFLICTS=$(git diff --name-only --diff-filter=U)
  warn "Merge conflicts in:"
  echo "$CONFLICTS"

  if echo "$CONFLICTS" | grep -qv "mix.exs"; then
    error "Unexpected conflict(s) outside mix.exs. Resolve manually then run:"
    error "  git add . && git merge --continue && git push origin main"
    exit 1
  fi

  # mix.exs conflict — keep ours as base and prompt to review
  warn "Conflict in mix.exs. Keeping pustaka version as base."
  warn "You should manually check if upstream added any new deps you want."
  echo ""
  warn "Upstream changes to mix.exs:"
  git diff "$LOCAL_BRANCH" "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" -- mix.exs || true
  echo ""

  # Take our version
  git checkout --ours mix.exs
  git add mix.exs

  echo -e "${YELLOW}Press ENTER after reviewing the diff above to continue, or Ctrl+C to abort and edit mix.exs manually.${NC}"
  read -r

  git merge --continue --no-edit
  info "Merge completed with mix.exs resolved to pustaka version ✓"
fi

# ── 3. Push to origin ────────────────────────────────────────────────────────
section "Pushing to origin (pustaka)"
git push "$ORIGIN_REMOTE" "$LOCAL_BRANCH"
info "Pushed to $ORIGIN_REMOTE/$LOCAL_BRANCH ✓"

section "Done"
info "pustaka is now synced with upstream voile."
