#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
SOURCE_ROOT="$REPO_ROOT/adapters/codex/skills"

SCOPE="user"
MODE="copy"
PROJECT_ROOT=""
TARGET_ROOT=""
ALSO_LEGACY="false"
LEGACY_TARGET_ROOT=""

SKILLS=(
  cx-help
  cx-init
  cx-prd
  cx-design
  cx-adr
  cx-plan
  cx-exec
  cx-fix
  cx-status
  cx-summary
  cx-config
  cx-scope
)

usage() {
  cat <<'EOF'
usage: install-codex.sh [OPTIONS]

Install the Codex adapter skill bundle for cx.

OPTIONS:
  --scope <user|project>          Install to user home or a project-local skill directory
  --project-root <path>           Project root when --scope project is used
  --target-root <path>            Explicit install root (overrides scope defaults)
  --mode <copy|symlink>           Install by copying files or creating symlinks
  --also-legacy                   Also install into legacy .codex/skills path
  --legacy-target-root <path>     Explicit legacy install root
  --help                          Show this help message
EOF
}

die() {
  echo "[install-codex] $*" >&2
  exit 1
}

log() {
  echo "[install-codex] $*"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)
        SCOPE="$2"
        shift 2
        ;;
      --project-root)
        PROJECT_ROOT="$2"
        shift 2
        ;;
      --target-root)
        TARGET_ROOT="$2"
        shift 2
        ;;
      --mode)
        MODE="$2"
        shift 2
        ;;
      --also-legacy)
        ALSO_LEGACY="true"
        shift
        ;;
      --legacy-target-root)
        LEGACY_TARGET_ROOT="$2"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

validate_args() {
  case "$SCOPE" in
    user|project) ;;
    *) die "--scope must be user or project" ;;
  esac

  case "$MODE" in
    copy|symlink) ;;
    *) die "--mode must be copy or symlink" ;;
  esac

  if [[ ! -d "$SOURCE_ROOT" ]]; then
    die "source skill directory missing: $SOURCE_ROOT"
  fi

  if [[ "$SCOPE" == "project" && -z "$PROJECT_ROOT" && -z "$TARGET_ROOT" ]]; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  fi
}

resolve_install_root() {
  if [[ -n "$TARGET_ROOT" ]]; then
    printf '%s\n' "$TARGET_ROOT"
    return
  fi

  if [[ "$SCOPE" == "project" ]]; then
    printf '%s/.agents/skills\n' "$PROJECT_ROOT"
    return
  fi

  printf '%s/.agents/skills\n' "$HOME"
}

resolve_legacy_root() {
  if [[ -n "$LEGACY_TARGET_ROOT" ]]; then
    printf '%s\n' "$LEGACY_TARGET_ROOT"
    return
  fi

  printf '%s/.codex/skills\n' "$HOME"
}

remove_target() {
  local path="$1"
  rm -rf "$path"
}

install_dir() {
  local src="$1"
  local dest="$2"

  remove_target "$dest"
  mkdir -p "$(dirname "$dest")"

  if [[ "$MODE" == "symlink" ]]; then
    ln -s "$src" "$dest"
  else
    cp -R "$src" "$dest"
  fi
}

install_shared_bundle() {
  local root="$1"
  local shared_dir="$root/cx-shared"

  mkdir -p "$shared_dir"
  remove_target "$shared_dir/references"
  remove_target "$shared_dir/scripts"

  if [[ "$MODE" == "symlink" ]]; then
    ln -s "$REPO_ROOT/references" "$shared_dir/references"
    ln -s "$REPO_ROOT/scripts" "$shared_dir/scripts"
  else
    cp -R "$REPO_ROOT/references" "$shared_dir/references"
    cp -R "$REPO_ROOT/scripts" "$shared_dir/scripts"
    chmod +x "$shared_dir"/scripts/*.sh
  fi

  cat > "$shared_dir/README.md" <<'EOF'
# cx-shared

这是 `cx` 在 Codex 侧安装后的共享资源目录。

- `references/`：共享协议、模板与说明
- `scripts/`：共享 core 脚本

Codex skills 通过相对路径 `../cx-shared/...` 读取这些内容。
EOF
}

install_bundle() {
  local root="$1"
  local skill=""

  mkdir -p "$root"

  for skill in "${SKILLS[@]}"; do
    if [[ ! -d "$SOURCE_ROOT/$skill" ]]; then
      die "missing skill source: $SOURCE_ROOT/$skill"
    fi
    install_dir "$SOURCE_ROOT/$skill" "$root/$skill"
  done

  install_shared_bundle "$root"
}

main() {
  parse_args "$@"
  validate_args

  local install_root legacy_root
  install_root=$(resolve_install_root)
  log "installing Codex adapter to $install_root (mode=$MODE)"
  install_bundle "$install_root"

  if [[ "$ALSO_LEGACY" == "true" || -n "$LEGACY_TARGET_ROOT" ]]; then
    legacy_root=$(resolve_legacy_root)
    log "also installing compatibility bundle to $legacy_root (mode=$MODE)"
    install_bundle "$legacy_root"
  fi

  log "installed skills: ${SKILLS[*]}"
  log "done"
}

main "$@"
