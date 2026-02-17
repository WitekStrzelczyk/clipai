#!/bin/bash
# Main entry point that orchestrates all quality checks
# Usage: ./quality-check.sh [--changed|--all]
# Default: --changed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODE="${1:---changed}"

cd "$PROJECT_ROOT"

echo "========================================"
echo "ClipAI Quality Check"
echo "Mode: $MODE"
echo "========================================"
echo ""

# Track overall status
OVERALL_STATUS=0

# 1. Format check (advisory only)
echo "--- Format Check - advisory ---"
if "$SCRIPT_DIR/format-check.sh" "$MODE"; then
    echo "[PASS] Format check completed"
else
    echo "[WARN] Format check had issues - non-blocking"
fi
echo ""

# 2. Lint (fails on errors)
echo "--- Lint Check ---"
if "$SCRIPT_DIR/lint.sh" "$MODE"; then
    echo "[PASS] Lint check passed"
else
    echo "[FAIL] Lint check failed"
    OVERALL_STATUS=1
fi
echo ""

# 3. Strict concurrency check (always on all files)
echo "--- Strict Concurrency Check ---"
if "$SCRIPT_DIR/strict-concurrency-check.sh"; then
    echo "[PASS] Strict concurrency check passed"
else
    echo "[FAIL] Strict concurrency check failed"
    OVERALL_STATUS=1
fi
echo ""

# Summary
echo "========================================"
if [ $OVERALL_STATUS -eq 0 ]; then
    echo "All quality checks passed!"
else
    echo "Some quality checks failed."
fi
echo "========================================"

exit $OVERALL_STATUS
