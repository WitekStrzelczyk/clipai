#!/bin/bash
# SwiftLint execution
# Usage: ./lint.sh [--changed|--all]
# Fails on errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---changed}"

cd "$PROJECT_ROOT"

# Check if swiftlint is available
if ! command -v swiftlint &>/dev/null; then
    echo "WARNING: swiftlint not found. Skipping lint. Install with: brew install swiftlint" >&2
    exit 0
fi

# Create temp cache directory
CACHE_DIR="${TMPDIR:-/tmp}/clipai-swiftlint-cache"
mkdir -p "$CACHE_DIR"

# Get files to lint
FILES=$("$SCRIPT_DIR/changed-swift-files.sh" "$MODE")

if [[ -z "$FILES" ]]; then
    echo "No Swift files to lint."
    exit 0
fi

echo "Running SwiftLint..."

# Convert files to space-separated list for swiftlint
FILE_LIST=$(echo "$FILES" | tr '\n' ' ')

# Run swiftlint with cache
swiftlint lint --cache-path "$CACHE_DIR" --config "$PROJECT_ROOT/.swiftlint.yml" $FILE_LIST 2>&1 || {
    echo "ERROR: SwiftLint found issues."
    exit 1
}

echo "SwiftLint passed."
