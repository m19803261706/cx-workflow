#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
FORCE="false"

usage() {
  cat <<'EOF'
usage: cx-core-migrate.sh [--project-root <path>] [--force]

Migrate a legacy project-level .claude/cx layout into the shared cx core control plane.
EOF
}

die() {
  echo "[migrate] $*" >&2
  exit 1
}

now_iso() {
  if [[ -n "${CX_CORE_NOW:-}" ]]; then
    printf '%s\n' "$CX_CORE_NOW"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-root)
        PROJECT_ROOT="$2"
        shift 2
        ;;
      --force)
        FORCE="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done
}

normalize_slug() {
  local raw_slug="$1"
  local developer_id="$2"

  if [[ -n "$developer_id" && "$raw_slug" == "$developer_id"-* ]]; then
    printf '%s\n' "${raw_slug#${developer_id}-}"
  else
    printf '%s\n' "$raw_slug"
  fi
}

map_feature_stage() {
  local status="$1"
  case "$status" in
    drafting|draft)
      printf 'draft\n'
      ;;
    designed|planned)
      printf 'planned\n'
      ;;
    ready)
      printf 'ready\n'
      ;;
    executing|in_progress)
      printf 'executing\n'
      ;;
    blocked)
      printf 'blocked\n'
      ;;
    completed)
      printf 'completed\n'
      ;;
    summarized|archived)
      printf 'archived\n'
      ;;
    *)
      printf 'draft\n'
      ;;
  esac
}

map_task_status() {
  local status="$1"
  case "$status" in
    ready|claimed|in_progress|blocked|completed|archived)
      printf '%s\n' "$status"
      ;;
    summarized)
      printf 'archived\n'
      ;;
    *)
      printf 'pending\n'
      ;;
  esac
}

doc_if_exists() {
  local dir="$1"
  shift
  local candidate=""
  for candidate in "$@"; do
    if [[ -f "$dir/$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
}

build_tasks_json() {
  local status_file="$1"
  local feature_title="$2"
  local feature_path="$3"

  jq -c \
    --arg feature_title "$feature_title" \
    --arg feature_path "$feature_path" \
    '
      (.tasks // [])
      | map(
          . as $task
          | {
              id: ($task.id // $task.number // 0),
              title: ($task.title // "未命名任务"),
              status: ($task.status // "pending")
            }
          | .status = (
              if (.status == "ready" or .status == "claimed" or .status == "in_progress" or .status == "blocked" or .status == "completed" or .status == "archived") then .status
              elif .status == "summarized" then "archived"
              else "pending"
              end
            )
          | .owner_session_id = null
          | .path = (
              if (($task.path // "") | length) > 0 then $task.path
              else ".claude/cx/" + $feature_path + "/任务/任务-" + (($task.id // $task.number // 0) | tostring) + ".md"
              end
            )
        )
    ' "$status_file"
}

main() {
  parse_args "$@"

  local cx_dir legacy_mode config_file project_status_file feature_root default_feature_path_prefix
  local core_dir core_project_dir core_feature_dir core_worktree_dir core_session_dir core_handoff_dir
  local migrated_at developer_id current_feature_raw current_feature_slug
  local runtime_dir cc_runtime_dir settings_file

  cx_dir="$PROJECT_ROOT/.claude/cx"
  core_dir="$cx_dir/core"
  core_project_dir="$core_dir/projects"
  core_feature_dir="$core_dir/features"
  core_worktree_dir="$core_dir/worktrees"
  core_session_dir="$core_dir/sessions"
  core_handoff_dir="$core_dir/handoffs"
  runtime_dir="$cx_dir/runtime"
  cc_runtime_dir="$runtime_dir/cc"
  settings_file="$PROJECT_ROOT/.claude/settings.json"
  migrated_at=$(now_iso)

  if [[ -f "$cx_dir/配置.json" && -f "$cx_dir/状态.json" ]]; then
    legacy_mode="zh"
    config_file="$cx_dir/配置.json"
    project_status_file="$cx_dir/状态.json"
    feature_root="$cx_dir/功能"
    default_feature_path_prefix="功能"
  elif [[ -f "$cx_dir/config.json" && -f "$cx_dir/status.json" ]]; then
    legacy_mode="en"
    config_file="$cx_dir/config.json"
    project_status_file="$cx_dir/status.json"
    feature_root="$cx_dir/features"
    default_feature_path_prefix="features"
  else
    die "no legacy cx layout detected under $cx_dir"
  fi

  if [[ -d "$core_dir" && "$FORCE" != "true" ]]; then
    die "shared cx core already exists at $core_dir (use --force to rebuild)"
  fi

  if [[ "$FORCE" == "true" ]]; then
    rm -rf "$core_dir"
  fi

  mkdir -p "$core_project_dir" "$core_feature_dir" "$core_worktree_dir" "$core_session_dir" "$core_handoff_dir" "$cc_runtime_dir"

  developer_id=$(jq -r '.developer_id // empty' "$config_file" 2>/dev/null)
  current_feature_raw=$(jq -r '.current_feature // empty' "$config_file" 2>/dev/null)
  current_feature_slug=""
  if [[ -n "$current_feature_raw" ]]; then
    current_feature_slug=$(normalize_slug "$current_feature_raw" "$developer_id")
  fi

  jq -n \
    --arg migrated_at "$migrated_at" \
    '{
      version: "1.0",
      current_feature: null,
      features: {},
      active_sessions: {},
      runtime_roots: {
        projects: ".claude/cx/core/projects",
        features: ".claude/cx/core/features",
        sessions: ".claude/cx/core/sessions",
        handoffs: ".claude/cx/core/handoffs",
        worktrees: ".claude/cx/core/worktrees",
        artifacts: {
          cx: ".claude/cx/runtime/cx",
          cc: ".claude/cx/runtime/cc",
          codex: ".claude/cx/runtime/codex"
        }
      },
      migrated_at: $migrated_at
    }' > "$core_project_dir/project.json"

  while IFS=$'\t' read -r raw_slug feature_title feature_path feature_status; do
    local target_slug source_dir status_file feature_stage prd_doc design_doc adr_doc summary_doc tasks_json docs_json feature_file worktree_file
    local worktree_path worktree_branch

    [[ -n "$raw_slug" ]] || continue
    target_slug=$(normalize_slug "$raw_slug" "$developer_id")
    if [[ -z "$feature_path" || "$feature_path" == "null" ]]; then
      if [[ "$legacy_mode" == "zh" ]]; then
        feature_path="$default_feature_path_prefix/$feature_title"
      else
        feature_path="$default_feature_path_prefix/$raw_slug"
      fi
    fi

    source_dir="$cx_dir/$feature_path"
    status_file="$source_dir/状态.json"
    if [[ ! -f "$status_file" ]]; then
      status_file="$source_dir/status.json"
    fi
    [[ -f "$status_file" ]] || die "feature status file missing for $raw_slug at $source_dir"

    if [[ -z "$feature_title" || "$feature_title" == "null" ]]; then
      feature_title=$(jq -r '.feature // .title // empty' "$status_file" 2>/dev/null)
    fi
    [[ -n "$feature_title" ]] || feature_title="$target_slug"

    feature_status=$(jq -r '.status // "drafting"' "$status_file" 2>/dev/null)
    feature_stage=$(map_feature_stage "$feature_status")
    prd_doc=$(doc_if_exists "$source_dir" "需求.md" "prd.md")
    design_doc=$(doc_if_exists "$source_dir" "设计.md" "design.md")
    adr_doc=$(doc_if_exists "$source_dir" "架构决策.md" "adr.md")
    summary_doc=$(doc_if_exists "$source_dir" "总结.md" "summary.md")
    tasks_json=$(build_tasks_json "$status_file" "$feature_title" "$feature_path")
    worktree_path="/worktrees/$target_slug"
    worktree_branch="feature/$target_slug"
    feature_file="$core_feature_dir/$target_slug.json"
    worktree_file="$core_worktree_dir/$target_slug.json"

    docs_json=$(jq -n \
      --arg prd "$prd_doc" \
      --arg design "$design_doc" \
      --arg adr "$adr_doc" \
      --arg summary "$summary_doc" '
        {
          prd: (if $prd == "" then null else $prd end),
          design: (if $design == "" then null else $design end),
          adr: (if $adr == "" then null else $adr end),
          summary: (if $summary == "" then null else $summary end)
        }
        | with_entries(select(.value != null))
      ')

    jq -n \
      --arg slug "$target_slug" \
      --arg title "$feature_title" \
      --arg stage "$feature_stage" \
      --arg updated_at "$migrated_at" \
      --arg branch "$worktree_branch" \
      --arg worktree_path "$worktree_path" \
      --arg feature_path "$feature_path" \
      --argjson docs "$docs_json" \
      --argjson tasks "$tasks_json" '
        {
          slug: $slug,
          title: $title,
          lifecycle: {
            stage: $stage,
            updated_at: $updated_at
          },
          planning_owner: null,
          execution_owner: null,
          worktree: {
            branch: $branch,
            worktree_path: $worktree_path,
            binding_status: "recommended"
          },
          lease: {
            runner: "cx",
            session_id: "cx-migration-placeholder",
            branch: $branch,
            worktree_path: $worktree_path,
            claimed_feature: $slug,
            claimed_tasks: [],
            claimed_at: $updated_at,
            last_heartbeat: $updated_at,
            expires_at: $updated_at
          },
          docs: $docs,
          tasks: $tasks,
          handoffs: []
        }
      ' > "$feature_file"

    jq -n \
      --arg feature_slug "$target_slug" \
      --arg worktree_path "$worktree_path" \
      --arg branch "$worktree_branch" \
      --arg updated_at "$migrated_at" '
        {
          feature_slug: $feature_slug,
          preferred_worktree_path: $worktree_path,
          preferred_branch: $branch,
          binding_status: "recommended",
          updated_at: $updated_at,
          bound_at: null,
        runner: null,
        session_id: null,
        current_worktree_path: null,
        current_branch: null,
        record_path: (".claude/cx/core/worktrees/" + $feature_slug + ".json")
      }
    ' > "$worktree_file"

    jq \
      --arg raw_slug "$raw_slug" \
      --arg slug "$target_slug" \
      --arg title "$feature_title" \
      --arg path ".claude/cx/core/features/$target_slug.json" \
      --arg stage "$feature_stage" \
      --arg worktree_path "$worktree_path" \
      --arg updated_at "$migrated_at" \
      --arg current_raw "$current_feature_raw" \
      --arg current_slug "$current_feature_slug" '
        .features[$slug] = {
          slug: $slug,
          title: $title,
          path: $path,
          lifecycle: $stage,
          worktree_path: $worktree_path,
          lease_session_id: null,
          last_updated: $updated_at
        }
        | .current_feature = (
            if $current_slug != "" and ($current_raw == $raw_slug or $current_slug == $slug) then $slug
            else .current_feature
            end
          )
      ' "$core_project_dir/project.json" > "$core_project_dir/project.tmp"
    mv "$core_project_dir/project.tmp" "$core_project_dir/project.json"
  done < <(
    jq -r '
      (.features // {})
      | to_entries[]
      | [
          .key,
          (.value.title // ""),
          (.value.path // ""),
          (.value.status // "")
        ]
      | @tsv
    ' "$project_status_file"
  )

  if [[ -f "$cx_dir/最近失败.json" ]]; then
    mv "$cx_dir/最近失败.json" "$cc_runtime_dir/最近失败.json"
  fi
  if [[ -f "$cx_dir/最近配置变更.json" ]]; then
    mv "$cx_dir/最近配置变更.json" "$cc_runtime_dir/最近配置变更.json"
  fi
  if [[ -f "$cx_dir/context-snapshot.md" ]]; then
    mv "$cx_dir/context-snapshot.md" "$cc_runtime_dir/context-snapshot.md"
  fi

  if [[ -f "$settings_file" ]] && rg -q 'cx-workflow-marketplace|stop-check\.sh|stop-failure\.sh|config-change\.sh' "$settings_file"; then
    echo "[migrate] detected project-copied hooks in .claude/settings.json; plugin-managed hooks should replace them after migration" >&2
  fi

  echo "[migrate] migrated legacy cx runtime at $cx_dir into shared core"
  echo "[migrate] core project: $core_project_dir/project.json"
}

main "$@"
