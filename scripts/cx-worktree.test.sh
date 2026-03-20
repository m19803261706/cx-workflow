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
rc1=0
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
