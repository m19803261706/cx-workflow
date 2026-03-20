#!/bin/bash
# cx-worktree-e2e.test.sh — E2E 集成测试：验证 worktree-per-feature 完整工作流
# 覆盖 Phase 1-4 全流程：创建/检测/列表/清理/分支命名/cx-lib 特征检测
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CX_WORKTREE="$SCRIPT_DIR/cx-worktree.sh"
CX_LIB="$SCRIPT_DIR/cx-lib.sh"
TEST_DIR=""
PASS=0
FAIL=0
TOTAL=0

# ---- 测试辅助函数 ----

setup() {
  TEST_DIR=$(mktemp -d)
  cd "$TEST_DIR"
  git init -q
  git commit --allow-empty -q -m "init"
}

teardown() {
  cd /
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

assert_eq() {
  local expected="$1" actual="$2" msg="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg (expected: '$expected', got: '$actual')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg (expected to contain: '$needle')"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  TOTAL=$((TOTAL + 1))
  if ! echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    echo "  ✓ $msg"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $msg (should NOT contain: '$needle')"
  fi
}

echo "=========================================="
echo "  CX Worktree-Per-Feature E2E Tests"
echo "=========================================="
echo ""

# ============================================================
# Scenario 1: 单个 feature worktree 完整生命周期
# ============================================================
echo "Scenario 1: Single feature worktree lifecycle"

setup

# 1a: 创建 worktree
output=$(bash "$CX_WORKTREE" create --feature feat-a --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=created" "create feat-a reports status=created"
assert_eq "true" "$(test -d "$TEST_DIR/.worktrees/feat-a" && echo true || echo false)" "worktree directory exists"
assert_contains "$output" "branch=feature/feat-a" "default branch prefix is feature/"

# 1b: 在 worktree 内部 check
cd "$TEST_DIR/.worktrees/feat-a"
output=$(bash "$CX_WORKTREE" check --feature feat-a 2>&1)
assert_contains "$output" "in_worktree=true" "check inside worktree detects in_worktree=true"
cd "$TEST_DIR"

# 1c: 在 main 上 check（应该失败，exit 1）
rc=0
output=$(bash "$CX_WORKTREE" check --project-root "$TEST_DIR" 2>&1) || rc=$?
assert_eq "1" "$rc" "check on main returns exit 1"
assert_contains "$output" "on_main=true" "check on main reports on_main=true"

# 1d: 在 main 上用 --inline check（应该成功）
output=$(bash "$CX_WORKTREE" check --inline --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "inline=true" "--inline allows main branch"

# 1e: cleanup 移除 worktree
output=$(bash "$CX_WORKTREE" cleanup --feature feat-a --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=removed" "cleanup reports status=removed"
assert_eq "false" "$(test -d "$TEST_DIR/.worktrees/feat-a" && echo true || echo false)" "worktree directory removed after cleanup"

teardown

# ============================================================
# Scenario 2: 并行 feature（CC + Codex 双 runner）
# ============================================================
echo ""
echo "Scenario 2: Parallel features (CC + Codex)"

setup

# 2a: 用不同 runner 创建两个 feature
output_a=$(bash "$CX_WORKTREE" create --feature feat-a --runner cc --project-root "$TEST_DIR" 2>&1)
output_b=$(bash "$CX_WORKTREE" create --feature feat-b --runner codex --project-root "$TEST_DIR" 2>&1)
assert_contains "$output_a" "branch=cc/feat-a" "CC runner creates cc/ branch prefix"
assert_contains "$output_b" "branch=codex/feat-b" "Codex runner creates codex/ branch prefix"

# 2b: 两个 worktree 目录都存在
assert_eq "true" "$(test -d "$TEST_DIR/.worktrees/feat-a" && echo true || echo false)" "feat-a worktree directory exists"
assert_eq "true" "$(test -d "$TEST_DIR/.worktrees/feat-b" && echo true || echo false)" "feat-b worktree directory exists"

# 2c: list 显示两个
output=$(bash "$CX_WORKTREE" list --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "count=2" "list shows count=2"
assert_contains "$output" "cc/feat-a" "list includes cc/feat-a"
assert_contains "$output" "codex/feat-b" "list includes codex/feat-b"

# 2d: 清理一个不影响另一个
bash "$CX_WORKTREE" cleanup --feature feat-a --project-root "$TEST_DIR" >/dev/null 2>&1
assert_eq "false" "$(test -d "$TEST_DIR/.worktrees/feat-a" && echo true || echo false)" "feat-a cleaned up"
assert_eq "true" "$(test -d "$TEST_DIR/.worktrees/feat-b" && echo true || echo false)" "feat-b still exists after feat-a cleanup"

# 2e: list 现在只有 1 个
output=$(bash "$CX_WORKTREE" list --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "count=1" "list shows count=1 after one cleanup"

teardown

# ============================================================
# Scenario 3: cx-lib.sh feature 检测
# ============================================================
echo ""
echo "Scenario 3: cx-lib.sh feature detection"

setup
source "$CX_LIB"

# 3a: feature/ 前缀
git checkout -q -b feature/test-slug
result=$(detect_feature_from_branch)
assert_eq "test-slug" "$result" "detect_feature_from_branch: feature/ prefix -> test-slug"

# 3b: cc/ 前缀
git checkout -q -b cc/my-feat
result=$(detect_feature_from_branch)
assert_eq "my-feat" "$result" "detect_feature_from_branch: cc/ prefix -> my-feat"

# 3c: codex/ 前缀
git checkout -q -b codex/other
result=$(detect_feature_from_branch)
assert_eq "other" "$result" "detect_feature_from_branch: codex/ prefix -> other"

# 3d: main 分支返回空
git checkout -q main
result=$(detect_feature_from_branch)
assert_eq "" "$result" "detect_feature_from_branch: main -> empty"

# 3e: resolve_current_feature 在 main 上回退到 状态.json
mkdir -p .claude/cx
cat > .claude/cx/状态.json << 'STATUSEOF'
{"current_feature": "fallback-slug"}
STATUSEOF
result=$(resolve_current_feature "$TEST_DIR")
assert_eq "fallback-slug" "$result" "resolve_current_feature: main falls back to 状态.json"

# 3f: resolve_current_feature 优先使用分支名
git checkout -q feature/test-slug
result=$(resolve_current_feature "$TEST_DIR")
assert_eq "test-slug" "$result" "resolve_current_feature: branch takes priority over 状态.json"

teardown

# ============================================================
# Scenario 4: Dashboard 聚合文件结构
# ============================================================
echo ""
echo "Scenario 4: Dashboard aggregation file structure"

setup

# 4a: 创建 core/projects/project.json，包含 2 个 features
mkdir -p "$TEST_DIR/.claude/cx/core/projects"
mkdir -p "$TEST_DIR/.claude/cx/core/features"

cat > "$TEST_DIR/.claude/cx/core/projects/project.json" << 'PROJEOF'
{
  "project_id": "test-project",
  "name": "Test Project",
  "features": ["feature-alpha", "feature-beta"],
  "current_feature": "feature-alpha"
}
PROJEOF

# 4b: 创建 2 个 feature 文件
cat > "$TEST_DIR/.claude/cx/core/features/feature-alpha.json" << 'FEATEOF'
{
  "slug": "feature-alpha",
  "title": "Alpha Feature",
  "status": "in_progress",
  "runner": "cc"
}
FEATEOF

cat > "$TEST_DIR/.claude/cx/core/features/feature-beta.json" << 'FEATEOF'
{
  "slug": "feature-beta",
  "title": "Beta Feature",
  "status": "planned",
  "runner": "codex"
}
FEATEOF

# 4c: 验证文件结构
assert_eq "true" "$(test -f "$TEST_DIR/.claude/cx/core/projects/project.json" && echo true || echo false)" "project.json exists"
assert_eq "true" "$(test -f "$TEST_DIR/.claude/cx/core/features/feature-alpha.json" && echo true || echo false)" "feature-alpha.json exists"
assert_eq "true" "$(test -f "$TEST_DIR/.claude/cx/core/features/feature-beta.json" && echo true || echo false)" "feature-beta.json exists"

# 4d: 验证 project.json 列出了两个 features
feature_count=$(jq '.features | length' "$TEST_DIR/.claude/cx/core/projects/project.json")
assert_eq "2" "$feature_count" "project.json lists 2 features"

# 4e: 验证 resolve_current_feature 可以从 project.json 回退
source "$CX_LIB"
# main 分支上，无 状态.json，回退到 project.json 的 current_feature
rm -f "$TEST_DIR/.claude/cx/状态.json"
result=$(resolve_current_feature "$TEST_DIR")
assert_eq "feature-alpha" "$result" "resolve_current_feature falls back to project.json"

# 4f: 验证每个 feature 文件的 slug 字段
alpha_slug=$(jq -r '.slug' "$TEST_DIR/.claude/cx/core/features/feature-alpha.json")
beta_slug=$(jq -r '.slug' "$TEST_DIR/.claude/cx/core/features/feature-beta.json")
assert_eq "feature-alpha" "$alpha_slug" "feature-alpha.json has correct slug"
assert_eq "feature-beta" "$beta_slug" "feature-beta.json has correct slug"

teardown

# ============================================================
# Scenario 5: 分支命名约定
# ============================================================
echo ""
echo "Scenario 5: Branch naming conventions"

setup

# 5a: 无 runner → feature/{slug}
output=$(bash "$CX_WORKTREE" create --feature naming-default --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "branch=feature/naming-default" "no runner -> feature/ prefix"

# 5b: --runner cc → cc/{slug}
output=$(bash "$CX_WORKTREE" create --feature naming-cc --runner cc --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "branch=cc/naming-cc" "--runner cc -> cc/ prefix"

# 5c: --runner codex → codex/{slug}
output=$(bash "$CX_WORKTREE" create --feature naming-codex --runner codex --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "branch=codex/naming-codex" "--runner codex -> codex/ prefix"

# 5d: 已存在的本地分支 → 复用（不重新创建）
bash "$CX_WORKTREE" cleanup --feature naming-default --project-root "$TEST_DIR" >/dev/null 2>&1
# 分支 feature/naming-default 还在，再次 create 应该复用
output=$(bash "$CX_WORKTREE" create --feature naming-default --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=created" "re-create from existing branch succeeds"
assert_contains "$output" "branch=feature/naming-default" "re-create uses existing branch name"

teardown

# ============================================================
# Scenario 6: Dirty worktree 安全检查
# ============================================================
echo ""
echo "Scenario 6: Dirty worktree safety"

setup

bash "$CX_WORKTREE" create --feature dirty-test --project-root "$TEST_DIR" >/dev/null 2>&1

# 在 worktree 中创建未提交的文件
echo "dirty content" > "$TEST_DIR/.worktrees/dirty-test/uncommitted.txt"

# 6a: 不带 --force 清理应该失败
rc=0
output=$(bash "$CX_WORKTREE" cleanup --feature dirty-test --project-root "$TEST_DIR" 2>&1) || rc=$?
assert_eq "1" "$rc" "cleanup dirty worktree fails without --force"
assert_contains "$output" "uncommitted" "error message mentions uncommitted changes"

# 6b: 带 --force 清理应该成功
output=$(bash "$CX_WORKTREE" cleanup --feature dirty-test --force --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=removed" "cleanup --force succeeds on dirty worktree"
assert_eq "false" "$(test -d "$TEST_DIR/.worktrees/dirty-test" && echo true || echo false)" "dirty worktree removed with --force"

teardown

# ============================================================
# Scenario 7: Flag 风格子命令（--create, --check, --list, --cleanup）
# ============================================================
echo ""
echo "Scenario 7: Flag-style subcommands"

setup

# 7a: --create
output=$(bash "$CX_WORKTREE" --create --feature flag-test --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=created" "--create flag style works"

# 7b: --list
output=$(bash "$CX_WORKTREE" --list --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "count=1" "--list flag style works"

# 7c: --check
cd "$TEST_DIR/.worktrees/flag-test"
output=$(bash "$CX_WORKTREE" --check --feature flag-test 2>&1)
assert_contains "$output" "in_worktree=true" "--check flag style works in worktree"
cd "$TEST_DIR"

# 7d: --cleanup
output=$(bash "$CX_WORKTREE" --cleanup --feature flag-test --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=removed" "--cleanup flag style works"

teardown

# ============================================================
# Scenario 8: .gitignore 安全性
# ============================================================
echo ""
echo "Scenario 8: .gitignore safety across operations"

setup

# 8a: 初始状态无 .gitignore
assert_eq "false" "$(test -f "$TEST_DIR/.gitignore" && echo true || echo false)" "no .gitignore initially"

# 8b: 第一次 create 自动添加 .worktrees 到 .gitignore
bash "$CX_WORKTREE" create --feature gi-test --project-root "$TEST_DIR" >/dev/null 2>&1
assert_eq "true" "$(test -f "$TEST_DIR/.gitignore" && echo true || echo false)" ".gitignore created"
assert_eq "true" "$(grep -qxF '.worktrees' "$TEST_DIR/.gitignore" && echo true || echo false)" ".worktrees added to .gitignore"

# 8c: 第二次 create 不会重复添加
bash "$CX_WORKTREE" create --feature gi-test2 --project-root "$TEST_DIR" >/dev/null 2>&1
count=$(grep -cxF '.worktrees' "$TEST_DIR/.gitignore")
assert_eq "1" "$count" ".worktrees not duplicated in .gitignore"

teardown

# ============================================================
# Scenario 9: 幂等创建（已存在的 worktree）
# ============================================================
echo ""
echo "Scenario 9: Idempotent create (existing worktree)"

setup

# 9a: 首次创建
output=$(bash "$CX_WORKTREE" create --feature idem-test --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=created" "first create succeeds"

# 9b: 再次创建同一 feature → status=exists
output=$(bash "$CX_WORKTREE" create --feature idem-test --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=exists" "second create reports exists (idempotent)"

teardown

# ============================================================
# Scenario 10: 清理不存在的 worktree（安全性）
# ============================================================
echo ""
echo "Scenario 10: Cleanup non-existent worktree (safety)"

setup

output=$(bash "$CX_WORKTREE" cleanup --feature ghost-feature --project-root "$TEST_DIR" 2>&1)
assert_contains "$output" "status=not_found" "cleanup non-existent worktree is safe"

teardown

# ============================================================
# Scenario 11: check 在 worktree 内但分支不匹配
# ============================================================
echo ""
echo "Scenario 11: Check with mismatched feature slug"

setup

bash "$CX_WORKTREE" create --feature mismatch-test --project-root "$TEST_DIR" >/dev/null 2>&1

# 在 worktree 内部但传入不同的 feature slug
cd "$TEST_DIR/.worktrees/mismatch-test"
rc=0
output=$(bash "$CX_WORKTREE" check --feature wrong-slug 2>&1) || rc=$?
assert_eq "1" "$rc" "check with wrong feature slug returns exit 1"
assert_contains "$output" "branch_matches=false" "check reports branch_matches=false"
cd "$TEST_DIR"

teardown

# ---- 测试结果汇总 ----
echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "=========================================="
[[ $FAIL -eq 0 ]] || exit 1
