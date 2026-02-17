#!/bin/bash
# Determines which Swift files to check
# Usage: ./changed-swift-files.sh [--all|--changed]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="${1:---changed}"

# Determine diff base
get_diff_base() {
    # Priority: QUALITY_DIFF_BASE env -> origin/$GITHUB_BASE_REF -> HEAD~1 -> fallback to --all
    if [[ -n "${QUALITY_DIFF_BASE:-}" ]]; then
        echo "$QUALITY_DIFF_BASE"
        return 0
    fi

    if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
        local remote_ref="origin/$GITHUB_BASE_REF"
        if git rev-parse --verify "$remote_ref" &>/dev/null; then
            echo "$remote_ref"
            return 0
        fi
    fi

    if git rev-parse --verify HEAD~1 &>/dev/null; then
        echo "HEAD~1"
        return 0
    fi

    # Fallback: no diff base available
    echo ""
}

cd "$PROJECT_ROOT"

if [[ "$MODE" == "--all" ]]; then
    # Get all Swift files tracked by git
    git ls-files '*.swift' 2>/dev/null || find . -name '*.swift' -not -path './.build/*' | sed 's|^\./||'
else
    DIFF_BASE=$(get_diff_base)

    if [[ -z "$DIFF_BASE" ]]; then
        echo "INFO: No diff base available, checking all files" >&2
        git ls-files '*.swift' 2>/dev/null || find . -name '*.swift' -not -path './.build/*' | sed 's|^\./||'
    else
        # Get changed Swift files (including staged but not committed)
        {
            git diff --name-only --diff-filter=d "$DIFF_BASE" -- '*.swift' 2>/dev/null || true
            git diff --name-only --diff-filter=d --cached -- '*.swift' 2>/dev/null || true
        } | sort -u | grep -v '^$' || true
    fi
fi
