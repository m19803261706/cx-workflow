# CX Worktree-Per-Feature Phase 1: 核心脚本 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建 `cx-worktree.sh` 核心脚本，提供 worktree 的创建、检测、列出、清理能力，作为 Phase 2-5 的基础。

**Architecture:** 新增一个独立的 shell 脚本 `scripts/cx-worktree.sh`，封装 `git worktree` 操作并集成 CX 的分支命名规范和 `.gitignore` 安全检查。参考 Superpowers `using-git-worktrees` 的目录检测优先级和安全验证模式。现有的 `cx-core-worktree.sh`（worktree 绑定记录）保持不变，新脚本专注于 git worktree 生命周期。

**Tech Stack:** Bash, Git, jq

**Spec:** `docs/superpowers/specs/2026-03-20-cx-worktree-per-feature-prd.md`

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `scripts/cx-worktree.sh` | Worktree 生命周期管理：create、check、list、cleanup 四个子命令 |
| `scripts/cx-worktree.test.sh` | 集成测试：在临时 git repo 中验证所有子命令 |

### Modified files

| File | Change |
|------|--------|
| `scripts/validate-cx-workflow.sh` | 新增 cx-worktree.sh 的存在性和可执行性检查 |

### No changes to

- `cx-core-worktree.sh` — 保持不变（负责 core binding 记录）
- 任何 SKILL.md — Phase 2 才改
- `状态.json` — Phase 3 才改

---

## Task 1: 创建 cx-worktree.sh 骨架 + --help

**Files:**
- Create: `scripts/cx-worktree.sh`

- [ ] **Step 1: 创建脚本骨架**

```bash
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

main() {
  parse_args "$@"
  resolve_project_root

  case "$SUBCOMMAND" in
    create)  cmd_create ;;
    check)   cmd_check ;;
    list)    cmd_list ;;
    cleanup) cmd_cleanup ;;
    *)       die "unknown subcommand: $SUBCOMMAND" ;;
  esac
}

cmd_create()  { die "not implemented yet"; }
cmd_check()   { die "not implemented yet"; }
cmd_list()    { die "not implemented yet"; }
cmd_cleanup() { die "not implemented yet"; }

main "$@"
```

- [ ] **Step 2: 设置可执行权限**

Run: `chmod +x scripts/cx-worktree.sh`

- [ ] **Step 3: 验证 --help 正常**

Run: `bash scripts/cx-worktree.sh --help`
Expected: 输出 usage 信息，exit 0

- [ ] **Step 4: 验证无参数报错**

Run: `bash scripts/cx-worktree.sh 2>&1; echo "exit=$?"`
Expected: 输出 usage，exit 1

- [ ] **Step 5: Commit**

```bash
git add scripts/cx-worktree.sh
git commit -m "feat(scripts): add cx-worktree.sh skeleton with subcommand routing"
```

---

## Task 2: 实现 worktree 目录检测逻辑

**Files:**
- Modify: `scripts/cx-worktree.sh`

参考 Superpowers `using-git-worktrees` 的目录检测优先级：
1. 检查 `.worktrees/` 是否存在（首选，隐藏目录）
2. 检查 `worktrees/` 是否存在（备选）
3. 都不存在时用默认 `.worktrees/`

- [ ] **Step 1: 添加 resolve_worktree_dir 函数**

在 `resolve_project_root` 函数之后添加：

```bash
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
```

- [ ] **Step 2: 更新 main 函数在路由前调用 resolve**

在 `main` 函数中，`case "$SUBCOMMAND"` 之前添加：

```bash
  resolve_worktree_dir
```

- [ ] **Step 3: 手动验证目录检测**

在一个有 `.worktrees/` 目录的项目中：
Run: `bash scripts/cx-worktree.sh list --feature test 2>&1`
Expected: 报 "not implemented yet"（目录检测不影响此步骤，但不应报错）

- [ ] **Step 4: Commit**

```bash
git add scripts/cx-worktree.sh
git commit -m "feat(scripts): add worktree directory detection and gitignore safety"
```

---

## Task 3: 实现 `create` 子命令

**Files:**
- Modify: `scripts/cx-worktree.sh`

- [ ] **Step 1: 实现 cmd_create**

替换 `cmd_create` 函数：

```bash
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
```

- [ ] **Step 2: 验证 create 基本流程**

Run: `cd /tmp && mkdir test-wt && cd test-wt && git init && git commit --allow-empty -m "init" && bash /Users/cx/.claude/plugins/marketplaces/cx-workflow-marketplace/scripts/cx-worktree.sh create --feature test-feat`
Expected: 创建 `.worktrees/test-feat` 目录，分支 `feature/test-feat`，输出 `status=created`

- [ ] **Step 3: 验证重复创建不报错**

Run:（在上面的 test-wt 目录中再次执行同一命令）
Expected: 输出 `status=exists`，不报错

- [ ] **Step 4: 清理测试目录**

Run: `rm -rf /tmp/test-wt`

- [ ] **Step 5: Commit**

```bash
git add scripts/cx-worktree.sh
git commit -m "feat(scripts): implement cx-worktree.sh create subcommand"
```

---

## Task 4: 实现 `check` 子命令

**Files:**
- Modify: `scripts/cx-worktree.sh`

- [ ] **Step 1: 实现 cmd_check**

替换 `cmd_check` 函数：

```bash
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/cx-worktree.sh
git commit -m "feat(scripts): implement cx-worktree.sh check subcommand"
```

---

## Task 5: 实现 `list` 子命令

**Files:**
- Modify: `scripts/cx-worktree.sh`

- [ ] **Step 1: 实现 cmd_list**

替换 `cmd_list` 函数：

```bash
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

    if [[ "$line2" =~ ^branch\ refs/heads/(.+)$ ]]; then
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/cx-worktree.sh
git commit -m "feat(scripts): implement cx-worktree.sh list subcommand"
```

---

## Task 6: 实现 `cleanup` 子命令

**Files:**
- Modify: `scripts/cx-worktree.sh`

- [ ] **Step 1: 实现 cmd_cleanup**

替换 `cmd_cleanup` 函数：

```bash
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

      if [[ "$line2" =~ ^branch\ refs/heads/(feature|cc|codex)/${FEATURE_SLUG}$ ]]; then
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/cx-worktree.sh
git commit -m "feat(scripts): implement cx-worktree.sh cleanup subcommand"
```

---

## Task 7: 集成测试

**Files:**
- Create: `scripts/cx-worktree.test.sh`

- [ ] **Step 1: 创建测试脚本**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CX_WORKTREE="$SCRIPT_DIR/cx-worktree.sh"
TEST_DIR=""
PASS=0
FAIL=0

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init
  git commit --allow-empty -m "init"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR"
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg (expected: $expected, got: $actual)"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg (expected to contain: $needle)"
  fi
}

echo "=== cx-worktree.sh tests ==="
echo ""

# Test 1: --help exits 0
echo "Test 1: --help"
local rc1=0
bash "$CX_WORKTREE" --help >/dev/null 2>&1 || rc1=$?
assert_eq "0" "$rc1" "--help exits 0"

# Test 2: create makes worktree and branch
echo "Test 2: create"
setup
output=$(bash "$CX_WORKTREE" create --feature test-feat --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=created" "create reports status=created"
assert_eq "true" "$(test -d "$TEST_DIR/.worktrees/test-feat" && echo true || echo false)" "worktree directory exists"
assert_contains "$(git -C "$TEST_DIR" branch)" "feature/test-feat" "branch created"
teardown

# Test 3: create with --runner sets branch prefix
echo "Test 3: create with --runner cc"
setup
output=$(bash "$CX_WORKTREE" create --feature my-feat --runner cc --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "branch=cc/my-feat" "branch has runner prefix"
teardown

# Test 4: create idempotent (existing worktree)
echo "Test 4: create idempotent"
setup
bash "$CX_WORKTREE" create --feature idem --project-root "$TEST_DIR" >/dev/null 2>&1
output=$(bash "$CX_WORKTREE" create --feature idem --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=exists" "second create reports exists"
teardown

# Test 5: check on main returns 1
echo "Test 5: check on main"
setup
output=$(bash "$CX_WORKTREE" check --project-root "$TEST_DIR" 2>&1 || true)
assert_contains "$output" "on_main=true" "check detects main branch"
teardown

# Test 6: check in feature worktree returns 0
echo "Test 6: check in worktree"
setup
bash "$CX_WORKTREE" create --feature check-test --project-root "$TEST_DIR" >/dev/null 2>&1
cd "$TEST_DIR/.worktrees/check-test"
output=$(bash "$CX_WORKTREE" check --feature check-test 2>&1)
assert_contains "$output" "in_worktree=true" "check detects worktree"
teardown

# Test 7: check --inline allows main
echo "Test 7: check --inline"
setup
output=$(bash "$CX_WORKTREE" check --inline --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "inline=true" "inline mode allows main"
teardown

# Test 8: list shows feature worktrees
echo "Test 8: list"
setup
bash "$CX_WORKTREE" create --feature list-a --project-root "$TEST_DIR" >/dev/null 2>&1
bash "$CX_WORKTREE" create --feature list-b --runner codex --project-root "$TEST_DIR" >/dev/null 2>&1
output=$(bash "$CX_WORKTREE" list --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "count=2" "list finds 2 worktrees"
assert_contains "$output" "feature/list-a" "list shows feature-a"
assert_contains "$output" "codex/list-b" "list shows codex feature-b"
teardown

# Test 9: cleanup removes worktree
echo "Test 9: cleanup"
setup
bash "$CX_WORKTREE" create --feature cleanup-test --project-root "$TEST_DIR" >/dev/null 2>&1
output=$(bash "$CX_WORKTREE" cleanup --feature cleanup-test --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=removed" "cleanup reports removed"
assert_eq "false" "$(test -d "$TEST_DIR/.worktrees/cleanup-test" && echo true || echo false)" "worktree directory removed"
teardown

# Test 10: cleanup of non-existent worktree is safe
echo "Test 10: cleanup non-existent"
setup
output=$(bash "$CX_WORKTREE" cleanup --feature ghost --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=not_found" "cleanup of missing worktree is safe"
teardown

# Test 11: .gitignore safety
echo "Test 11: gitignore safety"
setup
bash "$CX_WORKTREE" create --feature gitignore-test --project-root "$TEST_DIR" >/dev/null 2>&1
assert_eq "true" "$(grep -qxF '.worktrees' "$TEST_DIR/.gitignore" && echo true || echo false)" ".worktrees in gitignore"
teardown

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] || exit 1
```

- [ ] **Step 2: 设置可执行权限**

Run: `chmod +x scripts/cx-worktree.test.sh`

- [ ] **Step 3: 运行测试**

Run: `bash scripts/cx-worktree.test.sh`
Expected: 11 passed, 0 failed

- [ ] **Step 4: 修复失败的测试（如果有）**

根据失败信息修改 `cx-worktree.sh`，重新运行直到全部通过。

- [ ] **Step 5: Commit**

```bash
git add scripts/cx-worktree.test.sh
git commit -m "test(scripts): add integration tests for cx-worktree.sh"
```

---

## Task 8: 注册到验证脚本 + 最终检查

**Files:**
- Modify: `scripts/validate-cx-workflow.sh`

- [ ] **Step 1: 在 validate 脚本中添加 cx-worktree.sh 检查**

在 `validate-cx-workflow.sh` 中找到类似 `echo "[check] shared scripts exist"` 的位置，添加：

```bash
echo "[check] cx-worktree.sh exists and is executable"
test -x "$REPO_ROOT/scripts/cx-worktree.sh"
test -x "$REPO_ROOT/scripts/cx-worktree.test.sh"
```

- [ ] **Step 2: 运行完整验证**

Run: `bash scripts/validate-cx-workflow.sh`
Expected: 全部通过

- [ ] **Step 3: 运行 cx-worktree 测试确认无回归**

Run: `bash scripts/cx-worktree.test.sh`
Expected: 11 passed, 0 failed

- [ ] **Step 4: Commit**

```bash
git add scripts/validate-cx-workflow.sh
git commit -m "chore(scripts): register cx-worktree.sh in validation suite"
```

- [ ] **Step 5: Push**

```bash
git push
```
