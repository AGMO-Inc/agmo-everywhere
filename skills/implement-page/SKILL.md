---
name: implement-page
description: "Implement an entire Figma page by auto-splitting into frames with visual verification. Use whenever a user shares a figma.com/design URL and wants the page built in code. Triggers on '피그마 구현', '피그마 페이지', 'Figma implement'. Covers any multi-frame page: landing, dashboard, marketing, etc. Does NOT apply to Figma asset downloads or single component edits."
---

# Implement Page — Full Figma Page Frame-by-Frame Implementation

## Overview

Implements an entire Figma page by splitting it into top-level frames, dispatching `agmo:executor` for each frame, and delegating visual verification to `agmo:frontend`. The orchestrator coordinates the loop — it never edits files directly.

Why frame-by-frame? Large pages exceed MCP context limits when fetched at once. Splitting by frames gives each executor a focused, manageable scope while the orchestrator tracks cross-frame concerns (shared components, cumulative layout).

## Prerequisites

- Figma MCP server connected
- Dev server runnable in the project
- Playwright available (`npx playwright install chromium` if missing)

## Required User Input

Collect once before starting:

1. **Figma page URL** — `https://figma.com/design/:fileKey/:fileName?node-id=:nodeId`
2. **Dev server command** — default: `npm run dev`
3. **Dev server URL** — default: `http://localhost:3000`
4. **Page route** — e.g., `/`, `/dashboard`, `/pricing`

## Workflow

### Phase 1: Frame Discovery

1. **Parse the Figma URL:**
   - Extract `fileKey` from the path segment after `/design/`
   - Extract `nodeId` from the `node-id` query parameter
   - Convert hyphens to colons in nodeId (e.g., `1-2` → `1:2`)

2. **Fetch page structure:**
   ```
   get_metadata(fileKey, nodeId)
   ```
   Returns lightweight XML with node IDs, names, types, positions, and sizes.

3. **Extract top-level FRAME nodes:**
   - Collect `{id, name, y_position, width, height}` for each direct child FRAME
   - Sort by Y position (top to bottom) — this is the natural implementation order

4. **Present frame list and confirm:**
   ```
   ## Detected Frames (N total)
   1. Header (0, 0) — 1440×80
   2. Hero Section (0, 80) — 1440×600
   3. Features (0, 680) — 1440×400
   ...
   ```
   Ask: "이 순서대로 구현을 시작할까요?"

   If no FRAME nodes are found, the URL likely points to a single component. Suggest `implement-design` instead.

### Phase 2: Per-Frame Implementation Loop

#### Component Registry

The orchestrator maintains a text-format component registry that grows as frames are implemented. Pass it verbatim in every executor prompt so the executor knows what to reuse.

Format:
```
## Created Components
| Component | Path | Props |
|-----------|------|-------|
| Button | src/components/ui/Button.tsx | variant: "primary" | "secondary", size: "sm" | "md" | "lg" |
| SectionHeading | src/components/common/SectionHeading.tsx | title: string, subtitle?: string |
| FeatureCard | src/components/landing/FeatureCard.tsx | icon: ReactNode, title: string, description: string |
```

Update this registry after each successful frame implementation based on what the executor created.

---

For each frame (index N, 1-based), execute Steps 1–4:

#### Step 1: Fetch Design Data

Dispatch `agmo:explore` to fetch the design data:

```
Agent(subagent_type="agmo:explore", model="haiku", prompt="
  Fetch design data for Figma frame.
  1. Call get_design_context(fileKey='{fileKey}', nodeId='{frameId}')
  2. Call get_screenshot(fileKey='{fileKey}', nodeId='{frameId}')
  3. Return all design context data and confirm screenshot was retrieved.
  If get_design_context is truncated or too large:
    a. Call get_metadata(fileKey='{fileKey}', nodeId='{frameId}') to get children
    b. Fetch each major child with get_design_context individually
    c. Return all results combined
")
```

The screenshot from `get_screenshot` is the **Figma reference image** — keep it for Step 3.

#### Step 2: Implement

Dispatch `agmo:executor` with sonnet (standard complexity):

```
Agent(subagent_type="agmo:executor", model="sonnet", prompt="
  Implement Frame {N}/{total}: '{frame_name}'

  ## Design Context
  {design_context_from_step_1}

  ## Figma Reference
  [Figma screenshot from Step 1]

  ## Component Registry — Reuse These
  {component_registry}

  ## Implementation Rules
  1. ASSET DOWNLOADS: If the Figma MCP response includes localhost URLs for images,
     icons, or SVGs, download and save them to the project's asset directory.
     Do NOT add new icon packages.
  2. PROJECT CONVENTIONS: The Figma MCP output (React + Tailwind) is a design
     reference, not final code. Replace Tailwind utilities with the project's
     design system tokens. Reuse existing components from the registry above.
  3. VISUAL PARITY: Match the Figma design closely. Use design tokens from Figma
     where available. When project tokens conflict with Figma values, prefer project
     tokens but adjust spacing/sizing to maintain visual fidelity.
  4. ACCESSIBILITY: Semantic HTML, ARIA attributes, keyboard navigation (WCAG 2.1 AA).

  ## Output
  After implementation, list any new components you created in this format:
  | Component | Path | Props |
  |-----------|------|-------|
  | CompName | src/path/to/Comp.tsx | prop1: type, prop2: type |
")
```

After the executor completes, update the component registry with any new components.

#### Step 3: Visual Verification

This step delegates comparison to `agmo:frontend` because visual reasoning benefits from opus-level analysis.

**3a. Capture browser screenshot:**

```bash
node {SKILL_DIR}/scripts/capture-screenshot.js \
  --url "{dev_server_url}{route}" \
  --output /tmp/implement-page/frame-{N}.png \
  --full-page \
  --width 1440 --height 900
```

Why `--full-page`: Individual frames often render below the viewport fold. A viewport-only capture at 1440×900 would miss them entirely. The full-page screenshot captures everything, and the frontend agent compares the relevant vertical section against the Figma frame screenshot.

**3b. Dispatch agmo:frontend for visual comparison:**

```
Agent(subagent_type="agmo:frontend", prompt="
  ## Mode: visual
  ## Visual Verification: Frame {N}/{total} — '{frame_name}'

  Compare these two images:
  1. FIGMA REFERENCE: [Figma screenshot from Step 1]
  2. BROWSER RESULT: [Browser screenshot from /tmp/implement-page/frame-{N}.png]

  The browser screenshot is a full-page capture. Focus on the section that
  corresponds to frame '{frame_name}' (approximate Y position: {y_pos}px,
  height: {height}px from the Figma layout).

  Return your verdict using the visual mode output format.
")
```

Note: agmo:frontend is model-fixed to opus, so do NOT pass a model parameter.

**3c. Handle verdict:**

- **PASS** (score >= 7, no layout-breaking issues) → proceed to Step 4
- **FAIL** → dispatch `agmo:executor` with the frontend agent's issue list:
  ```
  Agent(subagent_type="agmo:executor", model="sonnet", prompt="
    Fix visual issues in Frame {N}: '{frame_name}'

    ## Issues from Visual Review
    {frontend_issues_list}

    ## Reference Images
    - Figma: [Figma screenshot]
    - Current browser: [Browser screenshot]

    Fix each listed issue. Focus on the specific CSS properties and components mentioned.
  ")
  ```
  Then re-capture and re-verify (back to 3a).

  Maximum 3 verification rounds per frame. After 3 failures, log remaining issues and continue to the next frame — do not block the entire page on one stubborn frame.

#### Step 4: Progress Report

After each frame, report to the user:

```
## Frame {N}/{total}: {frame_name} — {PASS|FAIL}
Verification: {PASS on attempt 1 | PASS on attempt 2 | FAIL after 3 attempts}
New components: {list or "none"}
{If FAIL: remaining issues summary}
```

### Phase 3: Final Verification & Completion

After all frames are implemented:

**1. Full-page visual check:**

Capture the Figma page screenshot and browser full-page screenshot:

```
get_screenshot(fileKey="{fileKey}", nodeId="{pageNodeId}")
```

```bash
node {SKILL_DIR}/scripts/capture-screenshot.js \
  --url "{dev_server_url}{route}" \
  --full-page \
  --output /tmp/implement-page/full-page.png \
  --width 1440 --height 900
```

Dispatch `agmo:frontend` to compare the full page:

```
Agent(subagent_type="agmo:frontend", prompt="
  ## Mode: visual
  ## Final Page Verification

  Compare full-page Figma design vs browser implementation.
  1. FIGMA: [full page screenshot]
  2. BROWSER: [full page screenshot from /tmp/implement-page/full-page.png]

  Focus on:
  - Cross-frame spacing and transitions (gaps between sections)
  - Overall visual rhythm and consistency
  - Any missing sections

  Return your verdict using the visual mode output format.
  PASS threshold for final: score >= 8.
")
```

If NEEDS_POLISH, dispatch one final `agmo:executor` round for cross-frame spacing fixes.

### Phase 3.5: Responsive Verification (Optional)

**2. Responsive check (optional):**

If the user requested responsive verification or the Figma design includes mobile/tablet variants, dispatch `agmo:frontend` in responsive mode:

```
Agent(subagent_type="agmo:frontend", prompt="
  ## Mode: responsive

  Verify responsive behavior for {route}.
  Screenshot script: {SKILL_DIR}/scripts/capture-screenshot.js
  Dev server URL: {dev_server_url}{route}

  Capture and evaluate at: mobile (375px), tablet (768px), desktop (1440px).
")
```

**3. Completion report:**

```
## implement-page Complete

### Implemented Frames
- [x] Frame 1: Header — PASS
- [x] Frame 2: Hero Section — PASS (2nd attempt)
- [ ] Frame 3: Footer — PARTIAL (differences logged)

### Component Registry (Final)
| Component | Path | Props |
|-----------|------|-------|
| Button | src/components/ui/Button.tsx | variant, size |
| FeatureCard | src/components/landing/FeatureCard.tsx | icon, title, description |

### Remaining Issues
- Frame 3: gradient color mismatch in footer background
```

**4. Save to Obsidian:**

Dispatch `agmo:archivist` to save the implementation record:

```
Agent(subagent_type="agmo:archivist", model="haiku", prompt="
  Save implementation record to Obsidian vault.

  Use vault-save.sh with:
  --project '{project_name}'
  --type 'impl'
  --title 'Figma Page Implementation: {route}'

  Content: the completion report above, including frame results,
  component registry, and remaining issues.
")
```

## Error Handling

| Situation | Action |
|-----------|--------|
| `get_metadata` fails | Verify URL format and Figma MCP connection. Ask user to check file permissions. |
| `get_design_context` truncated | Split into children via `get_metadata`, fetch each child individually. |
| Dev server not running | Ask user to start it. Wait for confirmation before proceeding. |
| Playwright not installed | Run `npx playwright install chromium`, then retry. |
| Browser screenshot fails | Verify dev server URL and route are correct. Ask user if the route requires auth. |
| Visual verification 3x fail | Log remaining differences, continue to next frame. |
| No FRAME nodes in metadata | URL likely points to a component. Suggest using `implement-design` instead. |
| Figma screenshot too large/slow | Reduce frame scope — fetch child sections individually. |
