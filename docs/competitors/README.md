# Competitor Analysis

Feature analysis of existing macOS clipboard managers to inform ClipAI development.

## Overview

This directory contains detailed feature breakdowns of competing clipboard managers. Use these documents to:

1. **Benchmark features** - Understand what users expect
2. **Identify gaps** - Find opportunities for differentiation
3. **Track implementation** - Compare our progress against market standards

## Competitors Documented

| Competitor | Type | Status | Link |
|------------|------|--------|------|
| Clipy | Open Source | Documented | [clipy.md](clipy.md) |

## Feature Status Summary

A quick reference for tracking implementation progress across all competitors.

### Must-Have (MVP)

| Feature | Status | Notes |
|---------|--------|-------|
| Background clipboard monitoring | Planned | Core functionality |
| Local storage (SQLite/Realm) | Planned | Text and images |
| Menu UI with global shortcut | Planned | Primary interface |
| Paste simulation (Cmd+V) | Planned | Essential UX |

### Status Legend

- **Implemented** - Feature complete and tested
- **In Progress** - Currently being developed
- **Planned** - Scheduled for development
- **Not Planned** - Intentionally excluded

## Adding New Competitors

When documenting a new competitor:

1. Create `[competitor-name].md` using the template in [template.md](template.md)
2. Extract features into comparable categories
3. Update the status summary table above
4. Note any unique differentiators

---

*Last reviewed: 2026-02-17*
*Review cycle: quarterly*
*Status: current*
