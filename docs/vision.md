---
last_reviewed: 2026-02-17
review_cycle: quarterly
status: current
---

# ClipAI Product Vision

> ClipAI transforms every clipboard item into enriched, actionable knowledge.

## Executive Summary

ClipAI is an AI-powered clipboard manager for macOS that goes beyond simple history storage. Every clipboard capture is automatically analyzed by AI, enriching the JSON entry with deeper understanding and context. This creates a growing personal knowledge base that learns from what you copy.

**Key Differentiator:** While competitors store clipboard history, ClipAI *understands* what you copy.

---

## Vision Layers

### Layer 1: Intelligent Clipboard Management (MVP)

The foundation matches existing clipboard managers:

- Background clipboard monitoring
- Searchable history with Raycast-style UI
- Snippets for reusable content
- Privacy controls (app ignore lists)

See [TODO.md](../TODO.md) for implementation details.

### Layer 2: AI-Enriched Knowledge Capture (Primary Vision)

When a user copies something, ClipAI analyzes and extends it automatically:

| Content Type | AI Enhancement |
|--------------|----------------|
| **Famous Quote** | Identify source (book, speech, author), context, related works |
| **Code Snippet** | Explain what the code does, language, dependencies, usage examples |
| **Mathematical Equation** | Explain the formula, variables, practical applications |
| **Article Excerpt** | Summarize key points, identify topic, related subjects |
| **URL/Link** | Extract metadata, title, summary, key content |
| **Contact Info** | Parse name, email, phone, company, social profiles |
| **Generic Text** | Categorize, extract entities, detect intent |

Enriched data is stored in `~/clipai/knowledge` as JSON, building a personal knowledge base over time.

### Layer 3: Knowledge to Action (Secondary Vision)

Clips become actionable through intelligent suggestions:

| Clip Content | Suggested Action |
|--------------|------------------|
| Grocery list | Convert to macOS Reminders to-do list |
| Meeting notes | Parse into action items |
| Recipe ingredients | Generate shopping list |
| Code error | Search Stack Overflow / suggest fixes |
| Date/Time | Create Calendar event |
| Email address | Prompt to create Contact |

This transforms ClipAI from passive storage into an active assistant.

---

## Competitive Differentiation

| Feature | Clipy | ClipAI |
|---------|-------|--------|
| Clipboard History | Yes | Yes |
| Snippets | Yes | Yes |
| AI Analysis | No | **Core Feature** |
| Knowledge Enrichment | No | **Core Feature** |
| Action Suggestions | No | **Secondary Vision** |
| Learning User Patterns | No | Future |

See [competitors/](competitors/) for detailed competitor analysis.

---

## Target Users

| User Type | Value Proposition |
|-----------|-------------------|
| **Researchers** | Capture quotes with automatic source attribution |
| **Developers** | Code snippets with explanations and context |
| **Students** | Formulas and concepts with learning aids |
| **Knowledge Workers** | Building personal knowledge base passively |
| **Productivity Enthusiasts** | Actionable clipboard items that save time |

---

## Technical Flow

```
User copies
    |
    v
ClipAI captures
    |
    v
AI analyzes --> Enriched JSON stored in ~/clipai/knowledge
    |                    |
    v                    v
Action suggested    Knowledge base grows
    |                    |
    v                    v
User executes       Pattern learning (future)
```

---

## How This Vision Informs User Stories

The user stories in [TODO.md](../TODO.md) represent Layer 1 (MVP). Each story contributes to the foundation that enables AI enrichment:

| Story | Vision Connection |
|-------|-------------------|
| Story 1: Background Monitoring | Enables automatic capture for AI analysis |
| Story 2: Menu Bar & Overlay | Primary interface for viewing enriched clips |
| Story 3: Display History List | Shows clips with AI-enriched metadata |
| Story 7: Search Clipboard History | Searches both content and AI-generated context |
| Story 10: Save and Manage Snippets | Persistent knowledge that can be AI-enhanced |

**The JSON schema in TODO.md** is designed to accommodate AI-enriched fields:

```json
{
  "id": "uuid-v4",
  "content": "...",
  "content_type": "text|image",
  "source_app": "Safari",
  "source_url": "https://...",
  "timestamp": "...",
  "metadata": { ... },
  "ai_enrichment": {
    "category": "quote",
    "source_attribution": { ... },
    "summary": "...",
    "entities": [...],
    "suggested_actions": [...]
  }
}
```

### Data Storage: Unique Key Upsert Behavior

ClipAI uses a **unique key** approach to prevent duplicate entries:

1. **Unique Key**: The combination of `source_app` + `content` forms a natural key
2. **Upsert Behavior**:
   - If a clip with the same key already exists: Only update the `timestamp` to now
   - If the clip is new: Insert it as a new entry
3. **Benefit**: No duplicate entries for the same content from the same app

This ensures that repeatedly copying the same text (e.g., a frequently-used code snippet) doesn't clutter the history with redundant entries. The timestamp update keeps frequently-used content fresh in the history.

#### Storage Location

All clips are stored in a single file: `~/clipai/knowledge.json`

```json
{
  "clips": [
    {
      "id": "uuid-v4",
      "content": "...",
      "content_type": "text",
      "source_app": "Safari",
      "source_url": "https://...",
      "timestamp": "2026-02-17T10:30:00Z",
      "metadata": {
        "text_length": 150
      }
    }
  ]
}
```

#### Browser URL Extraction

When copying from a supported browser, ClipAI can extract the current page URL from the browser's address bar. This feature requires **Accessibility permissions**.

Supported browsers:
- Safari (`com.apple.Safari`)
- Google Chrome (`com.google.Chrome`)
- Mozilla Firefox (`org.mozilla.firefox`)
- Microsoft Edge (`com.microsoft.edgemac`)

---

## Future Considerations

- **Privacy-preserving AI:** Local LLM options for sensitive content
- **Cross-device sync:** Encrypted knowledge base sync
- **Integration hooks:** API for third-party action plugins
- **Learning patterns:** Personalized suggestions based on usage

---

## Related Documents

- [TODO.md](../TODO.md) - User stories and implementation details
- [competitors/](competitors/) - Competitive feature analysis
- [README.md](README.md) - Documentation overview
