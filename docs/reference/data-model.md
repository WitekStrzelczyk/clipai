---
last_reviewed: 2026-02-17
review_cycle: quarterly
status: current
---

# ClipAI Data Model Reference

> Complete reference for ClipAI data structures, storage format, and key behaviors.

## Overview

ClipAI stores clipboard history in a single JSON file (`~/clipai/knowledge.json`). Each clip is a structured record with metadata about its source, content type, and capture time.

---

## Storage Architecture

### File Location

| Item | Path |
|------|------|
| Clips | `~/clipai/knowledge.json` |
| Snippets | `~/clipai/snippets.json` |
| Preferences | `~/Library/Preferences/com.clipai.app.plist` |
| Debug Log | `~/.clipai/clipai.log` |

### knowledge.json Structure

```json
{
  "clips": [
    { /* Clip object */ },
    { /* Clip object */ }
  ]
}
```

---

## Clip Model

### JSON Schema

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "content": "The actual text or base64-encoded image data",
  "content_type": "text",
  "source_app": "Safari",
  "source_url": "https://example.com/page",
  "timestamp": "2026-02-17T10:30:00Z",
  "metadata": {
    "text_length": 150
  }
}
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | UUID (string) | Yes | Unique identifier for the clip |
| `content` | string | Yes | The clip content (plain text or base64 for images) |
| `content_type` | enum | Yes | Either `"text"` or `"image"` |
| `source_app` | string | No | Name of the application the content was copied from |
| `source_url` | string (URL) | No | URL of the source page (for browser content) |
| `timestamp` | ISO8601 date | Yes | When the clip was captured |
| `metadata` | object | No | Additional content-specific metadata |

### Metadata Fields

For **text** clips:
```json
{
  "text_length": 150
}
```

For **image** clips:
```json
{
  "image_width": 800,
  "image_height": 600
}
```

---

## Unique Key Behavior (Upsert)

### Concept

ClipAI uses a **unique key** approach to prevent duplicate entries for the same content from the same application.

### Unique Key Definition

```
unique_key = source_app + content
```

### Upsert Logic

When a new clip is captured:

1. **Check for existing clip** with the same `source_app` + `content` combination
2. **If found**: Update only the `timestamp` to the current time (no new entry)
3. **If not found**: Insert as a new clip entry

### Benefits

- No duplicate clutter from repeatedly copying the same snippet
- Frequently-used content stays fresh in history (sorted by timestamp)
- Efficient storage - same content = same entry

### Example

1. User copies "Hello World" from Notes at 10:00
   - New clip created with timestamp 10:00
2. User copies "Hello World" from Notes again at 14:00
   - Same clip, timestamp updated to 14:00 (no new entry)
3. User copies "Hello World" from Safari at 15:00
   - New clip created (different source_app)

---

## Browser URL Extraction

### Overview

When copying from a supported browser, ClipAI can extract the current page URL from the browser's address bar using the macOS Accessibility API.

### Supported Browsers

| Browser | Bundle ID |
|---------|-----------|
| Safari | `com.apple.Safari` |
| Google Chrome | `com.google.Chrome` |
| Mozilla Firefox | `org.mozilla.firefox` |
| Microsoft Edge | `com.microsoft.edgemac` |

### Requirements

- **Accessibility permissions** must be granted to ClipAI
- If permissions are not available, URL extraction gracefully falls back to pasteboard data only

### Implementation

The `BrowserURLExtractor` class handles:
- Permission checking (`checkAccessibilityPermissions()`)
- Permission request prompting (`requestAccessibilityPermissions()`)
- Browser detection (`isSupportedBrowser(bundleIdentifier:)`)
- URL extraction via Accessibility API (`extractURL(from:)`)

### URL Priority

1. First, check pasteboard for direct URL data
2. If no URL in pasteboard and app is a supported browser, extract from address bar
3. If extraction fails or no permissions, `source_url` remains `null`

---

## Related Documents

- [vision.md](../vision.md) - Product vision and AI enrichment plans
- [TODO.md](../../TODO.md) - User stories and implementation details

---

*Last reviewed: 2026-02-17*
*Review cycle: quarterly*
