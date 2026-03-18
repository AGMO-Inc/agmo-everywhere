---
name: accessibility
description: Use to verify WCAG accessibility compliance of frontend/UI code. Auto-triggered by execute when TODO has frontend/ui tags. Triggers on "접근성", "accessibility", "WCAG".
---

# Accessibility — WCAG Static Code Review

## Overview

WCAG-based static code review for frontend/UI changes. Read-only analysis — no auto-fix is performed. Findings are classified as CRITICAL or MINOR.

## Process

Delegate to `agmo:explore` agent (haiku category):

1. Receive the list of changed files from execute
2. Read each file
3. Check each file against the 6-item checklist below
4. Classify each finding as CRITICAL or MINOR
5. Return structured report

## Checklist

1. **Semantic HTML** — `<div onclick>` instead of `<button>`, heading hierarchy (h1→h2→h3)
2. **ARIA attributes** — interactive elements must have `aria-label`, `role`, etc.
3. **Image alt text** — `<img>` must have meaningful `alt` attribute
4. **Form accessibility** — `<input>` must have associated `<label>`, error messages linked via `aria-describedby`
5. **Keyboard accessibility** — `tabIndex`, `onKeyDown` handlers, focus trap patterns
6. **Color contrast** — hardcoded color values checked against WCAG AA (4.5:1 ratio)

## Severity Classification

**CRITICAL:**
- Missing semantic elements for interactive controls (e.g., `<div onclick>` without `<button>`)
- Missing `alt` on informational images
- Form inputs without associated labels
- No keyboard access to interactive elements

**MINOR:**
- Heading hierarchy issues
- Missing `aria-describedby` on error messages
- Suboptimal `tabIndex` usage
- Color contrast on decorative elements

## Output Format

```
## Accessibility Review

### CRITICAL
- [file:line] [checklist item]: [finding] → [what to fix]

### MINOR
- [file:line] [checklist item]: [finding] → [suggestion]

### Summary
- CRITICAL: N issues
- MINOR: N issues
- Verdict: PASS (0 critical) / FAIL (1+ critical)
```

## Scope

**IN:**
- Changed files with frontend/ui tags only

**OUT:**
- Runtime/browser testing
- Dynamic state accessibility
- Full codebase audit
- Auto-fix

## Language

Respond to the user in Korean.
