#!/bin/bash
# Builds with strict concurrency checking
# Usage: ./strict-concurrency-check.sh
# Fails on build errors

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Building with strict concurrency checking..."

# Build with strict concurrency enabled
# Capture both stdout and stderr
BUILD_OUTPUT=$(swift build -Xswiftc -strict-concurrency=complete 2>&1) || {
    # Check if the failure is due to concurrency issues
    if echo "$BUILD_OUTPUT" | grep -qiE "(concurrency|sendable|actor-isolated|data race)"; then
        echo "ERROR: Strict concurrency issues detected:"
        echo "$BUILD_OUTPUT" | grep -iE "(concurrency|sendable|actor-isolated|data race)" || true
        exit 1
    fi
    # Other build errors
    echo "ERROR: Build failed:"
    echo "$BUILD_OUTPUT"
    exit 1
}

# Check for warnings in successful build
if echo "$BUILD_OUTPUT" | grep -qiE "warning:.*(concurrency|sendable|actor-isolated|data race)"; then
    echo "WARNING: Strict concurrency warnings detected:"
    echo "$BUILD_OUTPUT" | grep -iE "warning:.*(concurrency|sendable|actor-isolated|data race)" || true
fi

echo "Strict concurrency check passed."
