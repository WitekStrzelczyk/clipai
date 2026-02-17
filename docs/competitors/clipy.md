# Clipy Feature Specification

> Open-source macOS clipboard manager. Popular reference implementation for clipboard functionality.

---
**last_reviewed:** 2026-02-17
**review_cycle:** quarterly
**status:** current
**source:** https://github.com/Clipy/Clipy
---

## Executive Summary

Clipy is a widely-used open-source clipboard manager that extends macOS clipboard functionality. It serves as a baseline reference for expected features in a clipboard manager.

**Key Strengths:** Free, open-source, lightweight, Retina-optimized
**Key Limitations:** No cloud sync, no cross-device, no intelligent features

---

## Feature Categories

### 1. Clipboard History Management

Core functionality for extended clipboard storage.

| Feature | Description | Implementation Notes |
|---------|-------------|---------------------|
| Extended History | Retains history beyond macOS default (one item) | Core requirement |
| Text Support | Stores plain text clips | Basic data type |
| Image Support | Stores images (screenshots, photos) | Requires binary handling |
| Thumbnail Previews | Visual previews for images in history | UI enhancement |
| Drag & Drop | Drag items from history into other apps | macOS integration |

**Implementation Priority:** HIGH - Core feature set

### 2. Snippets (Static Templates)

Permanent text storage for reuse.

| Feature | Description | Implementation Notes |
|---------|-------------|---------------------|
| Snippet Registration | Save text blocks permanently | Persistent storage |
| Folder Organization | Organize snippets into folders | Hierarchy management |
| Instant Paste | Paste snippets without re-typing | Keyboard workflow |

**Implementation Priority:** MEDIUM - User retention feature

### 3. Access & Interface

User interaction methods.

| Feature | Description | Implementation Notes |
|---------|-------------|---------------------|
| Menu Bar Icon | Lives in menu bar for quick access | macOS NSStatusItem |
| Pop-up Menu | Customizable menu for history/snippets | Primary UI |
| Customizable Shortcuts | Keyboard shortcuts for menu/actions | Global hotkey |

**Implementation Priority:** HIGH - Primary user interface

### 4. Customization & Preferences

User configuration options.

| Feature | Description | Implementation Notes |
|---------|-------------|---------------------|
| History Limit | Define item count (10, 20, 30) | Storage management |
| Menu Appearance | Customize look (icon size, columns) | UI preferences |
| Login Items | Auto-launch at login | macOS integration |

**Implementation Priority:** LOW - Polish features

### 5. Privacy & Security

Data protection features.

| Feature | Description | Implementation Notes |
|---------|-------------|---------------------|
| Ignore List | Blacklist apps (password managers) | Privacy protection |
| Clear History | One-click history clear | User control |

**Implementation Priority:** HIGH - Trust requirement

### 6. Technical Features

Underlying technical capabilities.

| Feature | Description | Implementation Notes |
|---------|-------------|---------------------|
| Open Source | Free, auditable code | Transparency |
| Retina Display | High-resolution screen support | UI quality |

**Implementation Priority:** MEDIUM - Quality standard

---

## MVP Feature Set

Based on Clipy's core functionality, minimum viable product requirements:

1. **Background clipboard monitoring** - Continuously track clipboard changes
2. **Local storage** - SQLite or Realm for text and images
3. **Menu UI** - Accessible via global keyboard shortcut
4. **Paste simulation** - Insert selected item via Cmd+V simulation

---

## Implementation Tracking

Use this section to track ClipAI implementation against Clipy features.

### Clipboard History

| Feature | Status | ClipAI Notes |
|---------|--------|--------------|
| Extended History | Planned | |
| Text Support | Planned | |
| Image Support | Planned | |
| Thumbnail Previews | Planned | |
| Drag & Drop | Planned | |

### Snippets

| Feature | Status | ClipAI Notes |
|---------|--------|--------------|
| Snippet Registration | Planned | |
| Folder Organization | Planned | |
| Instant Paste | Planned | |

### Access & Interface

| Feature | Status | ClipAI Notes |
|---------|--------|--------------|
| Menu Bar Icon | Planned | |
| Pop-up Menu | Planned | |
| Customizable Shortcuts | Planned | |

### Customization

| Feature | Status | ClipAI Notes |
|---------|--------|--------------|
| History Limit | Planned | |
| Menu Appearance | Planned | |
| Login Items | Planned | |

### Privacy & Security

| Feature | Status | ClipAI Notes |
|---------|--------|--------------|
| Ignore List | Planned | |
| Clear History | Planned | |

---

## Differentiation Opportunities

Features Clipy lacks that ClipAI could implement:

| Opportunity | Value | Complexity |
|-------------|-------|------------|
| Cloud sync | Multi-device access | High |
| Intelligent search | AI-powered clip finding | Medium |
| Smart suggestions | Context-aware recommendations | High |
| Cross-platform | iOS/Windows support | High |
| Rich text support | Formatted content | Medium |
| Clipboard actions | Transform clips (uppercase, etc.) | Low |

---

## References

- **GitHub Repository:** https://github.com/Clipy/Clipy
- **License:** MIT
- **Language:** Swift/Objective-C
- **Minimum macOS:** 10.10+
