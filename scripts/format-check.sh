#!/bin/bash
# Check-only formatting (doesn't modify files)
# Usage: ./format-check.sh [--changed|--all]
# Advisory only - doesn't fail the check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---changed}"

cd "$PROJECT_ROOT"

# Check if swift-format is available
if ! command -v swift-format &>/dev/null; then
    echo "WARNING: swift-format not found. Skipping format check. Install with: brew install swift-format" >&2
    exit 0
fi

# Get files to check
FILES=$("$SCRIPT_DIR/changed-swift-files.sh" "$MODE")

if [[ -z "$FILES" ]]; then
    echo "No Swift files to check for formatting."
    exit 0
fi

echo "Checking Swift formatting (advisory only)..."

# Run swift-format in lint mode
FORMATTING_ISSUES=0
while IFS= read -r file; do
    if [[ -n "$file" ]]; then
        if ! swift-format lint --strict --configuration "$PROJECT_ROOT/.swift-format" "$file" 2>&1; then
            FORMATTING_ISSUES=1
        fi
    fi
done <<< "$FILES"

if [[ $FORMATTING_ISSUES -eq 1 ]]; then
    echo ""
    echo "ADVISORY: Some files have formatting issues."
    echo "Run './scripts/format.sh' to fix them automatically."
fi

# Always exit 0 (advisory only)
exit 0
