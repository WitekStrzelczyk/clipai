---
last_reviewed: 2026-02-17
review_cycle: quarterly
status: current
---

# Reference Documentation

Technical specifications and data model references for ClipAI.

## Documents

| Document | Description |
|----------|-------------|
| [data-model.md](data-model.md) | Complete reference for clip data structures, storage format, unique key upsert behavior, and browser URL extraction |

## Quick Reference

### File Locations

| Item | Path |
|------|------|
| Clips | `~/clipai/knowledge.json` |
| Snippets | `~/clipai/snippets.json` |
| Preferences | `~/Library/Preferences/com.clipai.app.plist` |

### Clip JSON Structure

```json
{
  "id": "uuid-v4",
  "content": "...",
  "content_type": "text|image",
  "source_app": "Safari",
  "source_url": "https://...",
  "timestamp": "2026-02-17T10:30:00Z",
  "metadata": { }
}
```

### Unique Key Behavior

- Key: `source_app` + `content`
- If duplicate: Update timestamp only (no new entry)
- Purpose: Prevent duplicate clutter, keep frequently-used content fresh

---

*Last reviewed: 2026-02-17*
