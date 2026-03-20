#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SUBCOMMAND=""
FEATURE_SLUG=""
RUNNER=""
PROJECT_ROOT=""
WORKTREE_DIR=""
BRANCH_PREFIX="feature"
INLINE="false"

log_ok()   { printf "${GREEN}✓${NC} %s\n" "$1"; }
log_warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }
log_err()  { printf "${RED}✗${NC} %s\n" "$1" >&2; }
log_info() { printf "${CYAN}→${NC} %s\n" "$1"; }

die() { log_err "$1"; exit 1; }

FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-worktree.sh <subcommand|--subcommand> [OPTIONS]

Subcommands (positional or flag style):
  create   / --create    Create a new worktree for a feature
  check    / --check     Check if CWD is in a valid feature worktree
  list     / --list      List all feature worktrees
  cleanup  / --cleanup   Remove a feature worktree after merge/discard

Options:
  --feature <slug>       Feature slug (required for create/check/cleanup)
  --runner <cc|codex>    Runner identity (affects branch prefix)
  --project-root <path>  Project root (default: git toplevel)
  --worktree-dir <path>  Worktree parent directory (default: auto-detect)
  --inline               Allow working on current branch without worktree
  --force                Force cleanup even with uncommitted changes
  --help                 Show this help
EOF
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  # First arg can be subcommand or flag
  case "$1" in
    create|check|list|cleanup)
      SUBCOMMAND="$1"; shift ;;
    --create)  SUBCOMMAND="create"; shift ;;
    --check)   SUBCOMMAND="check"; shift ;;
    --list)    SUBCOMMAND="list"; shift ;;
    --cleanup) SUBCOMMAND="cleanup"; shift ;;
    --help|-h) usage; exit 0 ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --feature)
        [[ $# -ge 2 ]] || die "--feature requires a value"
        FEATURE_SLUG="$2"; shift 2 ;;
      --runner)
        [[ $# -ge 2 ]] || die "--runner requires a value"
        RUNNER="$2"; shift 2 ;;
      --project-root)
        [[ $# -ge 2 ]] || die "--project-root requires a value"
        PROJECT_ROOT="$2"; shift 2 ;;
      --worktree-dir)
        [[ $# -ge 2 ]] || die "--worktree-dir requires a value"
        WORKTREE_DIR="$2"; shift 2 ;;
      --inline)         INLINE="true"; shift ;;
      --force)          FORCE="true"; shift ;;
      --help|-h)        usage; exit 0 ;;
      *)                die "unknown option: $1" ;;
    esac
  done
}

resolve_project_root() {
  if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
      || die "not in a git repository; pass --project-root"
  fi
}

resolve_worktree_dir() {
  if [[ -n "$WORKTREE_DIR" ]]; then
    return
  fi

  # Priority: .worktrees > worktrees > default .worktrees
  if [[ -d "$PROJECT_ROOT/.worktrees" ]]; then
    WORKTREE_DIR="$PROJECT_ROOT/.worktrees"
  elif [[ -d "$PROJECT_ROOT/worktrees" ]]; then
    WORKTREE_DIR="$PROJECT_ROOT/worktrees"
  else
    WORKTREE_DIR="$PROJECT_ROOT/.worktrees"
  fi
}

ensure_worktree_dir_ignored() {
  local dir_name gitignore_path
  dir_name=$(basename "$WORKTREE_DIR")
  gitignore_path="$PROJECT_ROOT/.gitignore"

  # Check .gitignore file content directly (not git check-ignore, which is affected by global/system gitignore)
  if [[ -f "$gitignore_path" ]] && grep -qxF "$dir_name" "$gitignore_path"; then
    return 0
  fi

  log_warn "$dir_name is not in .gitignore, adding it"
  echo "$dir_name" >> "$gitignore_path"
  log_ok "added $dir_name to .gitignore (not auto-committed — caller decides)"
}

resolve_branch_name() {
  if [[ -n "$RUNNER" ]]; then
    BRANCH_PREFIX="$RUNNER"
  fi
  printf '%s/%s\n' "$BRANCH_PREFIX" "$FEATURE_SLUG"
}

cmd_create() {
  [[ -n "$FEATURE_SLUG" ]] || die "create requires --feature <slug>"

  local branch_name worktree_path

  branch_name=$(resolve_branch_name)
  worktree_path="$WORKTREE_DIR/$FEATURE_SLUG"

  # Check if worktree already exists
  if [[ -d "$worktree_path" ]]; then
    log_warn "worktree already exists at $worktree_path"
    printf 'worktree_path=%s\n' "$worktree_path"
    printf 'branch=%s\n' "$branch_name"
    printf 'status=exists\n'
    return 0
  fi

  # Ensure parent dir exists and is ignored
  mkdir -p "$WORKTREE_DIR"
  ensure_worktree_dir_ignored

  # Check if branch already exists (remote or local)
  if git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    log_info "branch $branch_name already exists, creating worktree from it"
    git -C "$PROJECT_ROOT" worktree add "$worktree_path" "$branch_name"
  elif git -C "$PROJECT_ROOT" show-ref --verify --quiet "refs/remotes/origin/$branch_name" 2>/dev/null; then
    log_info "remote branch origin/$branch_name found, creating tracking worktree"
    git -C "$PROJECT_ROOT" worktree add "$worktree_path" -b "$branch_name" "origin/$branch_name"
  else
    log_info "creating new branch $branch_name"
    git -C "$PROJECT_ROOT" worktree add "$worktree_path" -b "$branch_name"
  fi

  log_ok "worktree created at $worktree_path (branch: $branch_name)"
  printf 'worktree_path=%s\n' "$worktree_path"
  printf 'branch=%s\n' "$branch_name"
  printf 'status=created\n'
}

cmd_check() {
  local current_branch current_toplevel

  current_branch=$(git branch --show-current 2>/dev/null || true)
  current_toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)

  # If --inline is set, allow main branch
  if [[ "$INLINE" == "true" ]]; then
    printf 'in_worktree=false\n'
    printf 'inline=true\n'
    printf 'branch=%s\n' "$current_branch"
    printf 'worktree_path=%s\n' "$current_toplevel"
    return 0
  fi

  # Check if on main/master (not allowed without --inline)
  case "$current_branch" in
    main|master)
      printf 'in_worktree=false\n'
      printf 'inline=false\n'
      printf 'branch=%s\n' "$current_branch"
      printf 'on_main=true\n'
      return 1
      ;;
  esac

  # Check if current directory is inside a worktree
  local is_worktree="false"
  if git worktree list --porcelain 2>/dev/null | grep -q "^worktree $current_toplevel$"; then
    # Verify it's not the main worktree
    local main_worktree
    main_worktree=$(git worktree list --porcelain 2>/dev/null | grep -m1 '^worktree ' | sed 's/^worktree //')
    if [[ "$current_toplevel" != "$main_worktree" ]]; then
      is_worktree="true"
    fi
  fi

  # If feature slug provided, check branch matches
  if [[ -n "$FEATURE_SLUG" && "$is_worktree" == "true" ]]; then
    local expected_patterns=("feature/$FEATURE_SLUG" "cc/$FEATURE_SLUG" "codex/$FEATURE_SLUG")
    local matches="false"
    for pattern in "${expected_patterns[@]}"; do
      if [[ "$current_branch" == "$pattern" ]]; then
        matches="true"
        break
      fi
    done

    if [[ "$matches" == "false" ]]; then
      log_warn "in worktree but branch $current_branch doesn't match feature $FEATURE_SLUG"
      printf 'in_worktree=true\n'
      printf 'branch_matches=false\n'
      printf 'branch=%s\n' "$current_branch"
      printf 'expected_feature=%s\n' "$FEATURE_SLUG"
      return 1
    fi
  fi

  printf 'in_worktree=%s\n' "$is_worktree"
  printf 'branch=%s\n' "$current_branch"
  printf 'worktree_path=%s\n' "$current_toplevel"
  if [[ "$is_worktree" == "true" ]]; then
    printf 'on_main=false\n'
  fi
  return 0
}

cmd_list() {
  local count=0

  log_info "Feature worktrees in $(basename "$PROJECT_ROOT"):"
  echo ""

  while IFS= read -r line; do
    local wt_path="" wt_branch="" wt_bare=""

    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${BASH_REMATCH[1]}"
    fi

    IFS= read -r line2 || true
    IFS= read -r line3 || true
    IFS= read -r _blank || true

    if [[ "$line3" =~ ^branch\ refs/heads/(.+)$ ]]; then
      wt_branch="${BASH_REMATCH[1]}"
    elif [[ "$line2" =~ ^branch\ refs/heads/(.+)$ ]]; then
      wt_branch="${BASH_REMATCH[1]}"
    fi

    # Skip main worktree (first entry) and bare entries
    if [[ $count -eq 0 ]]; then
      count=1
      continue
    fi

    # Only show feature-related branches
    case "$wt_branch" in
      feature/*|cc/*|codex/*)
        local slug="${wt_branch#*/}"
        printf '  %s  %-30s  %s\n' "$wt_branch" "$slug" "$wt_path"
        count=$((count + 1))
        ;;
    esac

  done < <(git -C "$PROJECT_ROOT" worktree list --porcelain 2>/dev/null)

  if [[ $count -le 1 ]]; then
    echo "  (no feature worktrees found)"
  fi

  echo ""
  printf 'count=%d\n' "$((count - 1))"
}

cmd_cleanup() {
  [[ -n "$FEATURE_SLUG" ]] || die "cleanup requires --feature <slug>"

  local branch_name worktree_path

  # Find the worktree for this feature
  local found="false"
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      local candidate_path="${BASH_REMATCH[1]}"
      IFS= read -r line2 || true
      IFS= read -r line3 || true
      IFS= read -r _blank || true

      if [[ "$line3" =~ ^branch\ refs/heads/(feature|cc|codex)/${FEATURE_SLUG}$ ]] \
         || [[ "$line2" =~ ^branch\ refs/heads/(feature|cc|codex)/${FEATURE_SLUG}$ ]]; then
        worktree_path="$candidate_path"
        branch_name="${BASH_REMATCH[1]}/$FEATURE_SLUG"
        found="true"
        break
      fi
    fi
  done < <(git -C "$PROJECT_ROOT" worktree list --porcelain 2>/dev/null)

  if [[ "$found" != "true" ]]; then
    log_warn "no worktree found for feature $FEATURE_SLUG"
    printf 'status=not_found\n'
    return 0
  fi

  # Safety: check for uncommitted changes unless --force
  if [[ "$FORCE" != "true" ]] && git -C "$worktree_path" status --porcelain 2>/dev/null | grep -q .; then
    die "worktree at $worktree_path has uncommitted changes; use --force to override"
  fi

  log_info "removing worktree at $worktree_path (branch: $branch_name)"
  git -C "$PROJECT_ROOT" worktree remove --force "$worktree_path" 2>/dev/null \
    || die "failed to remove worktree at $worktree_path"

  log_ok "worktree removed: $worktree_path"
  printf 'worktree_path=%s\n' "$worktree_path"
  printf 'branch=%s\n' "$branch_name"
  printf 'status=removed\n'
}

main() {
  parse_args "$@"
  resolve_project_root
  resolve_worktree_dir

  case "$SUBCOMMAND" in
    create)  cmd_create ;;
    check)   cmd_check ;;
    list)    cmd_list ;;
    cleanup) cmd_cleanup ;;
    *)       die "unknown subcommand: $SUBCOMMAND" ;;
  esac
}

main "$@"
