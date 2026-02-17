#!/bin/bash
# In-place formatting using swift-format
# Usage: ./format.sh [--changed|--all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---changed}"

cd "$PROJECT_ROOT"

# Check if swift-format is available
if ! command -v swift-format &>/dev/null; then
    echo "ERROR: swift-format not found. Install with: brew install swift-format" >&2
    exit 1
fi

# Get files to format
FILES=$("$SCRIPT_DIR/changed-swift-files.sh" "$MODE")

if [[ -z "$FILES" ]]; then
    echo "No Swift files to format."
    exit 0
fi

echo "Formatting Swift files..."
echo "$FILES" | xargs swift-format --in-place --configuration "$PROJECT_ROOT/.swift-format"
echo "Done."
