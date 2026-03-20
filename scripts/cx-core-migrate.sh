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

copy_doc_if_present() {
  local source_dir="$1"
  local source_doc="$2"
  local target_file="$3"

  if [[ -n "$source_doc" && -f "$source_dir/$source_doc" ]]; then
    mkdir -p "$(dirname "$target_file")"
    if [[ "$source_dir/$source_doc" != "$target_file" ]]; then
      cp "$source_dir/$source_doc" "$target_file"
    fi
  fi
}

copy_task_docs() {
  local source_dir="$1"
  local target_dir="$2"
  local task_file="" task_name="" task_number=""

  mkdir -p "$target_dir"
  shopt -s nullglob
  for task_file in "$source_dir"/tasks/task-*.md "$source_dir"/任务/任务-*.md; do
    task_name=$(basename "$task_file")
    if [[ "$task_name" =~ ([0-9]+)\.md$ ]]; then
      task_number="${BASH_REMATCH[1]}"
      cp "$task_file" "$target_dir/任务-$task_number.md"
    fi
  done
  shopt -u nullglob
}

resolve_feature_status_file() {
  local source_dir="$1"

  if [[ -f "$source_dir/状态.json" ]]; then
    printf '%s\n' "$source_dir/状态.json"
    return 0
  fi

  if [[ -f "$source_dir/status.json" ]]; then
    printf '%s\n' "$source_dir/status.json"
    return 0
  fi

  return 1
}

discover_feature_source() {
  local cx_root="$1"
  local raw_slug="$2"
  local developer_id="$3"
  local dir="" status_file="" prd_file="" candidate_slug="" candidate_title="" candidate_status="" candidate_path="" base_slug="" prd_slug=""

  shopt -s nullglob

  for dir in "$cx_root/功能"/*; do
    [[ -d "$dir" ]] || continue
    status_file=$(resolve_feature_status_file "$dir" || true)
    [[ -n "$status_file" ]] || continue

    candidate_slug=$(jq -r '.slug // empty' "$status_file" 2>/dev/null || true)
    candidate_title=$(jq -r '.feature // .title // empty' "$status_file" 2>/dev/null || true)
    candidate_status=$(jq -r '.status // empty' "$status_file" 2>/dev/null || true)

    if [[ -n "$candidate_slug" && ( "$raw_slug" == "$candidate_slug" || "$raw_slug" == "$(normalize_slug "$candidate_slug" "$developer_id")" ) ]]; then
      [[ -n "$candidate_title" ]] || candidate_title=$(basename "$dir")
      candidate_path="功能/$(basename "$dir")"
      printf '%s\t%s\t%s\t%s\n' "$dir" "$candidate_title" "$candidate_path" "$candidate_status"
      shopt -u nullglob
      return 0
    fi
  done

  for dir in "$cx_root/features"/*; do
    [[ -d "$dir" ]] || continue

    base_slug=$(basename "$dir")
    status_file=$(resolve_feature_status_file "$dir" || true)
    prd_file="$dir/prd.json"
    candidate_slug=""
    candidate_title=""
    candidate_status=""
    prd_slug=""

    if [[ -n "$status_file" ]]; then
      candidate_slug=$(jq -r '.slug // empty' "$status_file" 2>/dev/null || true)
      candidate_title=$(jq -r '.feature // .title // empty' "$status_file" 2>/dev/null || true)
      candidate_status=$(jq -r '.status // empty' "$status_file" 2>/dev/null || true)
    fi

    if [[ -f "$prd_file" ]]; then
      [[ -n "$candidate_title" ]] || candidate_title=$(jq -r '.feature_name // .title // empty' "$prd_file" 2>/dev/null || true)
      prd_slug=$(jq -r '.slug // empty' "$prd_file" 2>/dev/null || true)
      [[ -n "$candidate_slug" ]] || candidate_slug="$prd_slug"
    fi

    if [[ "$raw_slug" == "$base_slug" || \
          "$raw_slug" == "$(normalize_slug "$base_slug" "$developer_id")" || \
          ( -n "$candidate_slug" && "$raw_slug" == "$candidate_slug" ) || \
          ( -n "$candidate_slug" && "$raw_slug" == "$(normalize_slug "$candidate_slug" "$developer_id")" ) || \
          ( -n "$prd_slug" && "$raw_slug" == "$prd_slug" ) || \
          ( -n "$prd_slug" && "$raw_slug" == "$(normalize_slug "$prd_slug" "$developer_id")" ) ]]; then
      [[ -n "$candidate_title" ]] || candidate_title="$base_slug"
      candidate_path="features/$base_slug"
      printf '%s\t%s\t%s\t%s\n' "$dir" "$candidate_title" "$candidate_path" "$candidate_status"
      shopt -u nullglob
      return 0
    fi
  done

  shopt -u nullglob
  return 1
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
  local public_config_file public_status_file public_feature_root public_fix_root public_initialized_at
  local source_project_status_file

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
  public_config_file="$cx_dir/配置.json"
  public_status_file="$cx_dir/状态.json"
  public_feature_root="$cx_dir/功能"
  public_fix_root="$cx_dir/修复"

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

  mkdir -p "$core_project_dir" "$core_feature_dir" "$core_worktree_dir" "$core_session_dir" "$core_handoff_dir" "$cc_runtime_dir" "$public_feature_root" "$public_fix_root"

  developer_id=$(jq -r '.developer_id // empty' "$config_file" 2>/dev/null)
  current_feature_raw=$(jq -r '.current_feature // empty' "$config_file" 2>/dev/null)
  current_feature_slug=""
  if [[ -n "$current_feature_raw" ]]; then
    current_feature_slug=$(normalize_slug "$current_feature_raw" "$developer_id")
  fi
  source_project_status_file="$project_status_file"
  if [[ "$project_status_file" == "$public_status_file" ]]; then
    source_project_status_file=$(mktemp)
    cp "$project_status_file" "$source_project_status_file"
  fi

  public_initialized_at=$(jq -r '.initialized_at // .last_updated // empty' "$source_project_status_file" 2>/dev/null)
  if [[ -z "$public_initialized_at" || "$public_initialized_at" == "null" ]]; then
    public_initialized_at="$migrated_at"
  fi

  jq -n \
    --slurpfile cfg "$config_file" \
    --arg current_feature "$current_feature_slug" '
      ($cfg[0] // {}) as $cfg
      | {
          version: "3.0",
          developer_id: ($cfg.developer_id // ""),
          github_sync: ($cfg.github_sync // "local"),
          current_feature: (if $current_feature == "" then "" else $current_feature end),
          agent_teams: ($cfg.agent_teams // true),
          code_review: ($cfg.code_review // true),
          auto_memory: ($cfg.auto_memory // true),
          worktree_isolation: ($cfg.worktree_isolation // true),
          auto_format: ($cfg.auto_format // {enabled: true, formatter: "auto"}),
          hooks: {
            session_start: ($cfg.hooks.session_start // true),
            pre_compact: ($cfg.hooks.pre_compact // true),
            post_edit_format: ($cfg.hooks.post_edit_format // true),
            notification: ($cfg.hooks.notification // true)
          }
        }
    ' > "$public_config_file"

  jq -n \
    --slurpfile status "$source_project_status_file" \
    --arg initialized_at "$public_initialized_at" \
    --arg migrated_at "$migrated_at" \
    --arg current_feature "$current_feature_slug" '
      ($status[0] // {}) as $status
      | {
          initialized_at: $initialized_at,
          last_updated: $migrated_at,
          current_feature: (if $current_feature == "" then null else $current_feature end),
          features: {},
          fixes: (($status.fixes // {}) | if type == "object" then . else {} end)
        }
    ' > "$public_status_file"

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
    local public_feature_dir public_task_dir public_feature_status_file
    local fallback_source_dir fallback_title fallback_path fallback_status fallback_info

    [[ -n "$raw_slug" ]] || continue
    target_slug=$(normalize_slug "$raw_slug" "$developer_id")

    source_dir=""
    status_file=""

    if [[ -n "$feature_path" && "$feature_path" != "null" ]]; then
      source_dir="$cx_dir/$feature_path"
      status_file=$(resolve_feature_status_file "$source_dir" || true)
    fi

    if [[ -z "$feature_title" || "$feature_title" == "null" || -z "$feature_path" || "$feature_path" == "null" || -z "$status_file" ]]; then
      fallback_info=$(discover_feature_source "$cx_dir" "$raw_slug" "$developer_id" || true)
      if [[ -n "$fallback_info" ]]; then
        IFS=$'\t' read -r fallback_source_dir fallback_title fallback_path fallback_status <<< "$fallback_info"
        [[ -n "$feature_title" && "$feature_title" != "null" ]] || feature_title="$fallback_title"
        if [[ -z "$feature_path" || "$feature_path" == "null" || -z "$status_file" ]]; then
          feature_path="$fallback_path"
          source_dir="$fallback_source_dir"
          status_file=$(resolve_feature_status_file "$source_dir" || true)
        fi
        [[ -n "$feature_status" && "$feature_status" != "null" ]] || feature_status="$fallback_status"
      fi
    fi

    if [[ -z "$feature_path" || "$feature_path" == "null" ]]; then
      if [[ "$legacy_mode" == "zh" && -n "$feature_title" && "$feature_title" != "null" ]]; then
        feature_path="$default_feature_path_prefix/$feature_title"
      else
        feature_path="$default_feature_path_prefix/$raw_slug"
      fi
      source_dir="$cx_dir/$feature_path"
      status_file=$(resolve_feature_status_file "$source_dir" || true)
    fi

    [[ -n "$status_file" && -f "$status_file" ]] || die "feature status file missing for $raw_slug at $source_dir"

    if [[ -z "$feature_title" || "$feature_title" == "null" ]]; then
      feature_title=$(jq -r '.feature // .title // empty' "$status_file" 2>/dev/null)
    fi
    [[ -n "$feature_title" ]] || feature_title="$target_slug"

    public_feature_dir="$public_feature_root/$feature_title"
    public_task_dir="$public_feature_dir/任务"
    public_feature_status_file="$public_feature_dir/状态.json"

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
      --arg prd "$(if [[ -n "$prd_doc" ]]; then printf '需求.md'; fi)" \
      --arg design "$(if [[ -n "$design_doc" ]]; then printf '设计.md'; fi)" \
      --arg adr "$(if [[ -n "$adr_doc" ]]; then printf '架构决策.md'; fi)" \
      --arg summary "$(if [[ -n "$summary_doc" ]]; then printf '总结.md'; fi)" '
        {
          prd: (if $prd == "" then null else $prd end),
          design: (if $design == "" then null else $design end),
          adr: (if $adr == "" then null else $adr end),
          summary: (if $summary == "" then null else $summary end)
        }
        | with_entries(select(.value != null))
      ')

    mkdir -p "$public_task_dir"
    copy_doc_if_present "$source_dir" "$prd_doc" "$public_feature_dir/需求.md"
    copy_doc_if_present "$source_dir" "$design_doc" "$public_feature_dir/设计.md"
    copy_doc_if_present "$source_dir" "$adr_doc" "$public_feature_dir/架构决策.md"
    copy_doc_if_present "$source_dir" "$summary_doc" "$public_feature_dir/总结.md"
    copy_task_docs "$source_dir" "$public_task_dir"

    jq \
      --arg title "$feature_title" \
      --arg slug "$target_slug" \
      --arg status "$feature_status" \
      --arg updated_at "$migrated_at" \
      --arg prd "$(if [[ -n "$prd_doc" ]]; then printf '需求.md'; fi)" \
      --arg design "$(if [[ -n "$design_doc" ]]; then printf '设计.md'; fi)" \
      --arg summary "$(if [[ -n "$summary_doc" ]]; then printf '总结.md'; fi)" '
        .feature = $title
        | .slug = $slug
        | .status = $status
        | .created_at = (.created_at // $updated_at)
        | .last_updated = $updated_at
        | .docs = (
            (.docs // {})
            + (if $prd == "" then {} else {prd: $prd} end)
            + (if $design == "" then {} else {design: $design} end)
            + (if $summary == "" then {} else {summary: $summary} end)
          )
      ' "$status_file" > "$public_feature_status_file"

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

    jq \
      --arg slug "$target_slug" \
      --arg title "$feature_title" \
      --arg path "功能/$feature_title" \
      --arg status "$feature_status" \
      --arg updated_at "$migrated_at" '
        .features[$slug] = {
          title: $title,
          path: $path,
          status: $status,
          last_updated: $updated_at
        }
      ' "$public_status_file" > "$public_status_file.tmp"
    mv "$public_status_file.tmp" "$public_status_file"

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
    {
      jq -r '
        (.features // {})
        | if type == "object" then to_entries[] else empty end
        | [
            .key,
            (.value.title // ""),
            (.value.path // ""),
            (.value.status // "")
          ]
        | @tsv
      ' "$source_project_status_file"

      if [[ -d "$cx_dir/features" ]]; then
        shopt -s nullglob
        for discovered_dir in "$cx_dir/features"/*; do
          [[ -d "$discovered_dir" ]] || continue
          discovered_base=$(basename "$discovered_dir")
          discovered_status=$(resolve_feature_status_file "$discovered_dir" || true)
          discovered_title=""
          if [[ -n "$discovered_status" ]]; then
            discovered_title=$(jq -r '.feature // .title // empty' "$discovered_status" 2>/dev/null || true)
          fi
          if [[ -z "$discovered_title" && -f "$discovered_dir/prd.json" ]]; then
            discovered_title=$(jq -r '.feature_name // .title // empty' "$discovered_dir/prd.json" 2>/dev/null || true)
          fi
          printf '%s\t%s\t%s\t%s\n' "$discovered_base" "$discovered_title" "features/$discovered_base" "$(if [[ -n "$discovered_status" ]]; then jq -r '.status // ""' "$discovered_status" 2>/dev/null; fi)"
        done
        shopt -u nullglob
      fi

      if [[ -d "$public_feature_root" ]]; then
        shopt -s nullglob
        for discovered_dir in "$public_feature_root"/*; do
          [[ -d "$discovered_dir" ]] || continue
          discovered_status=$(resolve_feature_status_file "$discovered_dir" || true)
          [[ -n "$discovered_status" ]] || continue
          discovered_slug=$(jq -r '.slug // empty' "$discovered_status" 2>/dev/null || true)
          [[ -n "$discovered_slug" ]] || continue
          discovered_title=$(jq -r '.feature // .title // empty' "$discovered_status" 2>/dev/null || true)
          [[ -n "$discovered_title" ]] || discovered_title=$(basename "$discovered_dir")
          printf '%s\t%s\t%s\t%s\n' "$discovered_slug" "$discovered_title" "功能/$(basename "$discovered_dir")" "$(jq -r '.status // ""' "$discovered_status" 2>/dev/null)"
        done
        shopt -u nullglob
      fi
    } | awk -F '\t' '
      {
        key = $1
        if (key == "") {
          next
        }

        if (!(key in order_seen)) {
          order[++count] = key
          order_seen[key] = 1
        }

        if ($2 != "" && titles[key] == "") {
          titles[key] = $2
        }
        if ($3 != "" && paths[key] == "") {
          paths[key] = $3
        }
        if ($4 != "" && statuses[key] == "") {
          statuses[key] = $4
        }
      }
      END {
        for (row_index = 1; row_index <= count; row_index++) {
          key = order[row_index]
          printf "%s\t%s\t%s\t%s\n", key, titles[key], paths[key], statuses[key]
        }
      }
    '
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

  if [[ "$source_project_status_file" != "$project_status_file" ]]; then
    rm -f "$source_project_status_file"
  fi
}

main "$@"
