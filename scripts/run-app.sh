#!/bin/bash

# ClipAI - Run App Script
# Kills existing instance, rebuilds, and runs the app

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Stopping existing ClipAI instance...${NC}"
pkill -f ClipAI 2>/dev/null || true
sleep 1

echo -e "${YELLOW}Building ClipAI...${NC}"
swift build 2>&1 | tail -5

echo -e "${GREEN}Starting ClipAI...${NC}"
.build/debug/ClipAI &
sleep 2

echo -e "${GREEN}=== ClipAI is running ===${NC}"
echo ""
echo "Features:"
echo "• Cmd+Shift+V - Toggle overlay"
echo "• Arrow keys - Navigate clips"
echo "• Enter - Paste selected clip"
echo "• ESC - Dismiss overlay"
echo ""
echo "Logs: tail -f ~/.clipai/clipai.log"
