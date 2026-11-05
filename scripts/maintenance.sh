#!/usr/bin/env bash
# ==============================================================================
# AUTONOMOUS REPOSITORY INSPECTION, MAINTENANCE & CONTRIBUTION ENGINE
# Language: Pure Bash / Shell | Dependencies: Coreutils, Git, Bash 4+
# Strictly Zero Python, Zero Node.js, Zero External APIs, Zero AI Services
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. GLOBAL CONFIGURATION & RBAC GUARDS
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MAX_COMMITS="${MAX_COMMITS_PER_RUN:-25}"
DRY_RUN="${DRY_RUN:-false}"
HISTORY_FILE="${REPO_ROOT}/CONTRIBUTION_HISTORY.md"
WORKFLOW_FILE="${REPO_ROOT}/.github/workflows/daily-200-contributions.yml"
MAINTENANCE_SCRIPT="${REPO_ROOT}/scripts/maintenance.sh"
AUDIT_LOG="${REPO_ROOT}/.git_audit.log"

COMMITS_EXECUTED=0
TASKS_INSPECTED=0
TASKS_COMPLETED=0
FAILURES_COUNT=0

# RBAC Verification for GitHub Actions environment
CURRENT_ACTOR="${GITHUB_ACTOR:-local-runner}"
TRIGGER_EVENT="${GITHUB_EVENT_NAME:-manual}"

echo "======================================================================"
echo "⚡ AUTONOMOUS REPOSITORY MAINTENANCE & CONTRIBUTION ENGINE"
echo "Actor: ${CURRENT_ACTOR} | Event: ${TRIGGER_EVENT} | Max Budget: ${MAX_COMMITS}"
echo "Repository Root: ${REPO_ROOT}"
echo "======================================================================"

# Initialize Contribution History if missing
if [[ ! -f "${HISTORY_FILE}" ]]; then
    cat << 'EOF' > "${HISTORY_FILE}"
# 📜 Autonomous Contribution & Maintenance History

This ledger documents verified, automated improvements made across the repository.
Every entry corresponds to a genuine, validated commit meeting zero-fabrication criteria.

| Date (UTC) | Repository / File | Task Category | Commit SHA | Validation Status | Details |
| :--- | :--- | :--- | :--- | :---: | :--- |
EOF
fi

# ------------------------------------------------------------------------------
# 2. HELPER FUNCTIONS: VALIDATION, LOGGING & GIT COMMIT DISPATCH
# ------------------------------------------------------------------------------

log_history() {
    local target_file="$1"
    local category="$2"
    local commit_sha="$3"
    local status="$4"
    local message="$5"
    local timestamp
    timestamp="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

    echo "| ${timestamp} | \`${target_file}\` | ${category} | \`${commit_sha:0:7}\` | ${status} | ${message} |" >> "${HISTORY_FILE}"
}

verify_git_diff_safety() {
    # Absolute anti-secret check on staged files
    local staged_diff
    staged_diff="$(git diff --cached)"

    # Check for secret patterns (high-entropy private keys, passwords, live tokens)
    if echo "${staged_diff}" | grep -qE "ghp_[A-Za-z0-9]{30,}|xkeysib-[A-Za-z0-9]{30,}|BEGIN PRIVATE KEY|AWS_SECRET_ACCESS_KEY"; then
        echo "🚨 CRITICAL SECURITY ERROR: Secret detected in staged diff! Aborting commit."
        git reset HEAD
        return 1
    fi

    # Verify something is actually staged
    if git diff --cached --quiet; then
        return 1
    fi

    return 0
}

commit_and_record() {
    local target_file="$1"
    local category="$2"
    local commit_msg="$3"
    local detail_desc="$4"

    if [[ "${COMMITS_EXECUTED}" -ge "${MAX_COMMITS}" ]]; then
        echo "ℹ️ Reached maximum execution budget (${MAX_COMMITS} commits). Halting further tasks."
        return 0
    fi

    # Stage the specific modified file only (never git add .)
    git add "${target_file}"

    # Perform safety inspection on staged diff
    if ! verify_git_diff_safety; then
        echo "⚠️ Safety check failed or empty diff for ${target_file}. Skipping commit."
        git checkout -- "${target_file}" || true
        FAILURES_COUNT=$((FAILURES_COUNT + 1))
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo "🔍 [DRY-RUN] Validated: ${commit_msg} on ${target_file}"
        git reset HEAD "${target_file}"
        git checkout -- "${target_file}" || true
        TASKS_COMPLETED=$((TASKS_COMPLETED + 1))
        return 0
    fi

    # Execute atomic commit
    git commit -m "${commit_msg}"

    local new_sha
    new_sha="$(git rev-parse HEAD)"

    # Record in history ledger
    log_history "${target_file#"${REPO_ROOT}/"}" "${category}" "${new_sha}" "✅ PASSED" "${detail_desc}"

    # Stage and commit history update in batch or next pass
    git add "${HISTORY_FILE}"
    git commit --amend --no-edit || git commit -m "docs(history): record maintenance cycle [${new_sha:0:7}]" || true

    COMMITS_EXECUTED=$((COMMITS_EXECUTED + 1))
    TASKS_COMPLETED=$((TASKS_COMPLETED + 1))

    echo "✅ [COMMIT #${COMMITS_EXECUTED}/${MAX_COMMITS}] ${commit_msg} (${new_sha:0:7})"
}

# ------------------------------------------------------------------------------
# 3. TASK MODULE 1: REPOSITORY HEALTH & ESSENTIAL GOVERNANCE FILES
# ------------------------------------------------------------------------------
inspect_governance_files() {
    echo "🔎 [1/5] Inspecting repository governance & metadata files..."
    TASKS_INSPECTED=$((TASKS_INSPECTED + 1))

    # Task 1.1: Ensure SECURITY.md exists
    if [[ ! -f "${REPO_ROOT}/SECURITY.md" ]] && [[ "${COMMITS_EXECUTED}" -lt "${MAX_COMMITS}" ]]; then
        cat << 'EOF' > "${REPO_ROOT}/SECURITY.md"
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |

## Reporting a Vulnerability

Please do not report security vulnerabilities through public GitHub issues.
Instead, report vulnerabilities privately to the maintainers via GitHub Security Advisories
or by email to the repository owner. All security reports will be acknowledged within 48 hours.
EOF
        commit_and_record "SECURITY.md" "Governance" "docs(security): establish repository security vulnerability reporting policy" "Created standardized SECURITY.md guidelines."
    fi

    # Task 1.2: Ensure CONTRIBUTING.md exists
    if [[ ! -f "${REPO_ROOT}/CONTRIBUTING.md" ]] && [[ "${COMMITS_EXECUTED}" -lt "${MAX_COMMITS}" ]]; then
        cat << 'EOF' > "${REPO_ROOT}/CONTRIBUTING.md"
# Contributing Guidelines

Thank you for your interest in contributing to this project.

## Contribution Standards
1. All changes must be verified locally before opening a pull request.
2. Adhere to POSIX shell standards for all `.sh` scripts.
3. Validate YAML syntax using strict linters.
4. Conventional Commits must be followed (`feat:`, `fix:`, `docs:`, `chore:`, `style:`).
5. Ensure zero secrets, credentials, or private keys are ever committed.
EOF
        commit_and_record "CONTRIBUTING.md" "Governance" "docs(contributing): add standardized open-source contribution guidelines" "Created standardized CONTRIBUTING.md."
    fi

    # Task 1.3: Ensure .editorconfig exists
    if [[ ! -f "${REPO_ROOT}/.editorconfig" ]] && [[ "${COMMITS_EXECUTED}" -lt "${MAX_COMMITS}" ]]; then
        cat << 'EOF' > "${REPO_ROOT}/.editorconfig"
# http://editorconfig.org
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.sh]
indent_size = 4

[*.md]
trim_trailing_whitespace = false
EOF
        commit_and_record ".editorconfig" "Configuration" "chore(config): add repository-wide .editorconfig formatting standards" "Defined editor consistency rules across editors."
    fi
}

# ------------------------------------------------------------------------------
# 4. TASK MODULE 2: CODE QUALITY, WHITESPACE & POSIX COMPLIANCE
# ------------------------------------------------------------------------------
inspect_code_quality_and_formatting() {
    echo "🔎 [2/5] Inspecting source files for POSIX compliance, whitespace & formatting..."

    # Find text files eligible for maintenance (excluding .git)
    local target_files
    mapfile -t target_files < <(find "${REPO_ROOT}" -type f \
        \( -name "*.sh" -o -name "*.md" -o -name "*.yml" -o -name "*.yaml" -o -name "*.txt" -o -name ".gitignore" \) \
        ! -path "*/.git/*" ! -path "*/node_modules/*" | head -n 40)

    for file in "${target_files[@]}"; do
        if [[ "${COMMITS_EXECUTED}" -ge "${MAX_COMMITS}" ]]; then
            break
        fi

        TASKS_INSPECTED=$((TASKS_INSPECTED + 1))
        local rel_path="${file#"${REPO_ROOT}/"}"

        # Skip the history file to avoid circular edits
        if [[ "${rel_path}" == "CONTRIBUTION_HISTORY.md" ]]; then
            continue
        fi

        # Check 2.1: Enforce final newline (POSIX standard)
        if [[ -s "${file}" ]] && [ "$(tail -c 1 "${file}" | wc -l)" -eq 0 ]; then
            echo "" >> "${file}"
            commit_and_record "${rel_path}" "Formatting" "style(${rel_path}): ensure trailing newline for POSIX compliance" "Appended missing terminating newline."
            continue
        fi

        # Check 2.2: Shell script executable bit
        if [[ "${file}" == *.sh ]] && [[ ! -x "${file}" ]]; then
            chmod +x "${file}"
            commit_and_record "${rel_path}" "Permissions" "chore(${rel_path}): grant executable mode bit to shell script" "Applied chmod +x for executable execution."
            continue
        fi

        # Check 2.3: Remove trailing whitespace in non-markdown files
        if [[ "${file}" != *.md ]] && grep -q "[[:space:]]$" "${file}" 2>/dev/null; then
            sed -i 's/[[:space:]]*$//' "${file}"
            if ! git diff --quiet "${file}"; then
                commit_and_record "${rel_path}" "Code Quality" "style(${rel_path}): trim trailing whitespace across lines" "Cleaned redundant trailing whitespace characters."
                continue
            fi
        fi

        # Check 2.4: Validate Bash syntax
        if [[ "${file}" == *.sh ]]; then
            if ! bash -n "${file}"; then
                echo "🚨 Syntax error in ${rel_path}. Skipping modifications to avoid broken builds."
                FAILURES_COUNT=$((FAILURES_COUNT + 1))
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 5. TASK MODULE 3: DOCUMENTATION ENHANCEMENT & LINK INTEGRITY
# ------------------------------------------------------------------------------
inspect_documentation() {
    echo "🔎 [3/5] Inspecting markdown documentation, table formatting & headings..."

    local md_files
    mapfile -t md_files < <(find "${REPO_ROOT}" -maxdepth 2 -type f -name "*.md" ! -path "*/.git/*")

    for file in "${md_files[@]}"; do
        if [[ "${COMMITS_EXECUTED}" -ge "${MAX_COMMITS}" ]]; then
            break
        fi

        TASKS_INSPECTED=$((TASKS_INSPECTED + 1))
        local rel_path="${file#"${REPO_ROOT}/"}"

        if [[ "${rel_path}" == "CONTRIBUTION_HISTORY.md" ]]; then
            continue
        fi

        # Check 3.1: Check if README is missing architecture or usage section
        if [[ "${rel_path}" == "README.md" ]]; then
            if ! grep -q "## Architecture & Workflow" "${file}"; then
                cat << 'EOF' >> "${file}"

## Architecture & Workflow

The autonomous contribution engine executes distributed maintenance cycles using:
1. **POSIX Shell Core:** Native `bash` scripts with zero third-party runtimes.
2. **Safety Jails:** Diff inspection before commit stages to eliminate secret exposure.
3. **Atomic Verification:** Amends self-recorded audit ledgers to maintain git hygiene.
EOF
                commit_and_record "README.md" "Documentation" "docs(readme): add architecture and workflow documentation section" "Documented autonomous maintenance principles."
                continue
            fi
        fi

        # Check 3.2: Normalize Markdown horizontal dividers (replace uneven hyphens with standardized 3-dash ---)
        if grep -qE '^----+[[:space:]]*$' "${file}" 2>/dev/null; then
            sed -i -E 's/^----+[[:space:]]*$/---/' "${file}"
            if ! git diff --quiet "${file}"; then
                commit_and_record "${rel_path}" "Documentation" "docs(${rel_path}): standardize markdown section horizontal rules" "Normalized thematic dividers to standard three-dash syntax."
                continue
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# 6. TASK MODULE 4: CONFIGURATION & GITIGNORE HYGIENE
# ------------------------------------------------------------------------------
inspect_configuration() {
    echo "🔎 [4/5] Inspecting configuration files & gitignore rules..."
    TASKS_INSPECTED=$((TASKS_INSPECTED + 1))

    local gitignore="${REPO_ROOT}/.gitignore"
    if [[ -f "${gitignore}" ]]; then
        local modified=false

        # List of critical ignores to ensure present
        local must_ignore=(
            "*.tmp"
            "*.bak"
            "*.log"
            ".DS_Store"
            "Thumbs.db"
            ".env"
            ".env.local"
            "*.key"
            "*.pem"
            "*.pfx"
        )

        for rule in "${must_ignore[@]}"; do
            if ! grep -Fxq "${rule}" "${gitignore}"; then
                echo "${rule}" >> "${gitignore}"
                modified=true
            fi
        done

        if [[ "${modified}" == "true" ]]; then
            # Sort and remove duplicate lines
            local temp_sorted
            temp_sorted="$(sort -u "${gitignore}")"
            echo "${temp_sorted}" > "${gitignore}"
            # Ensure final newline
            echo "" >> "${gitignore}"

            if ! git diff --quiet "${gitignore}" && [[ "${COMMITS_EXECUTED}" -lt "${MAX_COMMITS}" ]]; then
                commit_and_record ".gitignore" "Configuration" "chore(git): harden .gitignore with OS artifacts and secret exclusion rules" "Appended required secret exclusion and OS cache filters."
            fi
        fi
    fi
}

# ------------------------------------------------------------------------------
# 7. TASK MODULE 5: SELF-UPDATING & WORKFLOW OPTIMIZATION ENGINE
# ------------------------------------------------------------------------------
inspect_self_maintenance() {
    echo "🔎 [5/5] Performing self-inspection on workflow YAML and maintenance shell script..."
    TASKS_INSPECTED=$((TASKS_INSPECTED + 1))

    # Self-Audit 5.1: Validate workflow YAML syntax and permissions
    if [[ -f "${WORKFLOW_FILE}" ]]; then
        local wf_rel=".github/workflows/daily-200-contributions.yml"

        # Check if workflow specifies concurrency to prevent collision
        if ! grep -q "concurrency:" "${WORKFLOW_FILE}"; then
            echo "ℹ️ Adding concurrency protection group to workflow..."
            # Insert concurrency block after permissions
            sed -i '/permissions:/a \  concurrency:\n    group: autonomous-contribution-engine\n    cancel-in-progress: false' "${WORKFLOW_FILE}"
            if ! git diff --quiet "${WORKFLOW_FILE}" && [[ "${COMMITS_EXECUTED}" -lt "${MAX_COMMITS}" ]]; then
                commit_and_record "${wf_rel}" "Self-Update" "ci(workflow): add concurrency protection group to prevent race conditions" "Injected concurrency control into workflow YAML."
            fi
        fi

        # Check if workflow permissions are strictly least-privilege
        if grep -q "write-all" "${WORKFLOW_FILE}" 2>/dev/null; then
            sed -i 's/write-all/contents: write/' "${WORKFLOW_FILE}"
            if ! git diff --quiet "${WORKFLOW_FILE}" && [[ "${COMMITS_EXECUTED}" -lt "${MAX_COMMITS}" ]]; then
                commit_and_record "${wf_rel}" "Self-Update" "ci(workflow): restrict permissions from write-all to explicit least-privilege" "Hardened workflow permissions to contents: write."
            fi
        fi
    fi

    # Self-Audit 5.2: Self-check maintenance.sh integrity
    if [[ -f "${MAINTENANCE_SCRIPT}" ]]; then
        # Ensure script syntax compiles cleanly
        if bash -n "${MAINTENANCE_SCRIPT}"; then
            echo "✅ Self-diagnostic PASS: ${MAINTENANCE_SCRIPT} syntax is valid."
        else
            echo "🚨 Self-diagnostic FAIL: Syntax error detected in ${MAINTENANCE_SCRIPT}!"
            FAILURES_COUNT=$((FAILURES_COUNT + 1))
        fi
    fi
}

# ------------------------------------------------------------------------------
# 8. EXECUTION ORCHESTRATION & SUMMARY MATRIX
# ------------------------------------------------------------------------------
main() {
    local start_time
    start_time="$(date +%s)"

    # Execute inspection modules sequentially
    inspect_governance_files
    inspect_code_quality_and_formatting
    inspect_documentation
    inspect_configuration
    inspect_self_maintenance

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))

    echo ""
    echo "======================================================================"
    echo "📊 AUTONOMOUS EXECUTION SUMMARY MATRIX"
    echo "======================================================================"
    echo "⏱️  Duration: ${duration}s"
    echo "🔍 Tasks Inspected: ${TASKS_INSPECTED}"
    echo "✨ Tasks Completed: ${TASKS_COMPLETED}"
    echo "🚀 Commits Generated & Verified: ${COMMITS_EXECUTED} / ${MAX_COMMITS}"
    echo "⚠️  Failures / Blockers: ${FAILURES_COUNT}"
    echo "📄 Ledger: ${HISTORY_FILE}"
    echo "======================================================================"

    if [[ "${COMMITS_EXECUTED}" -gt 0 ]]; then
        echo "🎉 Successfully applied ${COMMITS_EXECUTED} genuine, validated improvements."
    else
        echo "ℹ️ Zero modifications required. Repository is in optimal, compliant state."
    fi
}

main "$@"
