#!/usr/bin/env bash
# ==============================================================================
# Unit & Regression Test Suite for Autonomous Maintenance Engine
# ==============================================================================
set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

assert_true() {
    local desc="$1"
    shift
    if "$@"; then
        echo "  ✅ PASS: ${desc}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  ❌ FAIL: ${desc}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== Running Maintenance Script Unit Tests ==="

# Test 1: Bash syntax verification
assert_true "scripts/maintenance.sh syntax check" bash -n scripts/maintenance.sh

# Test 2: Workflow YAML syntax presence
assert_true "Workflow file exists and is non-empty" test -s .github/workflows/daily-200-contributions.yml

# Test 3: Essential files presence
assert_true "README.md exists" test -f README.md
assert_true "CONTRIBUTION_HISTORY.md exists" test -f CONTRIBUTION_HISTORY.md
assert_true "SECURITY.md exists" test -f SECURITY.md
assert_true "CONTRIBUTING.md exists" test -f CONTRIBUTING.md
assert_true ".editorconfig exists" test -f .editorconfig

# Test 4: Verify executable bits
assert_true "scripts/maintenance.sh is executable" test -x scripts/maintenance.sh

echo "============================================="
echo "Test Results: ${TESTS_PASSED} Passed | ${TESTS_FAILED} Failed"
echo "============================================="

if [[ "${TESTS_FAILED}" -gt 0 ]]; then
    exit 1
fi
exit 0
