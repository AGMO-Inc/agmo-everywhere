---
name: implement-page-android
description: "Implement an entire Figma page as Android Jetpack Compose screens by auto-splitting into frames with visual verification. Use whenever a user shares a figma.com/design URL and wants the page built as Compose code. Triggers on '안드로이드 피그마', 'Android Figma', 'Compose 구현'. Covers any multi-frame page. Does NOT apply to Figma asset downloads or single component edits."
---

# Implement Page Android — Full Figma Page Frame-by-Frame Compose Implementation

## Overview

Implements an entire Figma page as Android Jetpack Compose screens by splitting it into top-level frames, dispatching `agmo:executor` for each frame, and delegating visual verification to `agmo:android-specialist`. The orchestrator coordinates the loop — it never edits files directly.

Why frame-by-frame? Large pages exceed MCP context limits when fetched at once. Splitting by frames gives each executor a focused, manageable scope while the orchestrator tracks cross-frame concerns (shared Composables, cumulative layout, Component Registry).

## Prerequisites

- Figma MCP server connected
- Android project with `build.gradle.kts` and Compose dependencies
- Compose Preview rendering environment — **required, skill will not proceed without one:**
  - [Paparazzi](https://github.com/cashapp/paparazzi) (recommended, JVM-only, no emulator needed)
  - [Roborazzi](https://github.com/takahirom/roborazzi) (Robolectric-based)
  - [Compose Preview Screenshot Testing](https://developer.android.com/studio/preview/compose-screenshot-testing)
- Gradle installed and configured

## Required User Input

Collect once before starting:

1. **Figma page URL** — `https://figma.com/design/:fileKey/:fileName?node-id=:nodeId`
2. **Android project path** — absolute path to project root
3. **Module name** — default: `app`
4. **Target package for generated screens** — auto-detect from existing code if not provided
5. **Dev server / emulator running** — if using adb fallback for screenshot capture

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
   1. TopAppBar (0, 0) — 360×56
   2. HeroSection (0, 56) — 360×240
   3. ContentList (0, 296) — 360×480
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
| Composable | Path | Parameters |
|------------|------|------------|
| AppButton | ui.components.AppButton | text: String, onClick: () -> Unit, style: ButtonStyle |
| SectionHeading | ui.components.SectionHeading | title: String, subtitle: String? |
| FeatureCard | ui.components.FeatureCard | icon: ImageVector, title: String, description: String |
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
  1. COMPOSABLE STRUCTURE: Generate @Composable functions following state hoisting pattern.
     UI state modeled as sealed class/interface. Parameters must be bindable.
  2. MATERIAL DESIGN 3: Use MaterialTheme tokens (colorScheme, typography, shapes) exclusively.
     NO hardcoded Color() or TextStyle() values.
  3. PREVIEWS: Generate both @Preview and @Preview(uiMode = UI_MODE_NIGHT_YES) for every screen.
     Save preview capture images to /tmp/implement-page-android/.
  4. KOTLIN IDIOMS: Apply extension functions, scope functions. Use Stable/Immutable
     parameters for recomposition optimization. Use remember / derivedStateOf appropriately.
  5. DIMENSIONS: Use dp for spacing and sizing, sp for text sizes only.
  6. ASSET DOWNLOADS: If Figma MCP response includes URLs for images or icons,
     download and save them to the project's res/drawable directory.
     Do NOT add new icon packages — use Material Icons Extended if available.
  7. DESIGN SYSTEM: Replace any Figma MCP generated raw values with project's
     design system tokens. Reuse existing Composables from the Component Registry above.

  ## Output
  After implementation, list any new Composables you created in this format:
  | Composable | Path | Parameters |
  |------------|------|------------|
  | CompName | package.path.CompName | param1: Type, param2: Type |
")
```

After the executor completes, update the Component Registry with any new Composables.

#### Step 2.5: Compile & Code Quality Verification

Run Gradle compilation to verify there are no Kotlin compile errors (max 3 retries):

```bash
./gradlew :{module}:compileDebugKotlin
```

If the project has Detekt or ktlint configured, also run static analysis:

```bash
./gradlew :{module}:detekt
# or
./gradlew :{module}:ktlintCheck
```

On failure:
- Parse the Gradle error log to identify the compile error
- Dispatch `agmo:executor` with the error details to fix it
- Re-run compilation to verify the fix

After 3 consecutive failures: log the compile errors, move on to the next frame — do not block the entire page.

#### Step 3: Visual Verification

This step delegates comparison to `agmo:android-specialist` because visual reasoning benefits from opus-level analysis.

**3a. Capture Compose Preview screenshot:**

```bash
bash scripts/capture-compose-preview.sh \
  --composable "com.example.ui.{ScreenName}_Preview" \
  --output /tmp/implement-page-android/frame-{N}.png \
  --project-dir /path/to/project \
  --module app \
  --width 360 --height 640
```

If the capture script fails, check that the screenshot testing library is properly configured in `build.gradle.kts`. The skill cannot proceed without a working capture pipeline — see Prerequisites.

**3b. Dispatch agmo:android-specialist for visual comparison:**

```
Agent(subagent_type="agmo:android-specialist", prompt="
  ## Mode: visual
  ## Visual Verification: Frame {N}/{total} — '{frame_name}'

  Compare these two images:
  1. FIGMA REFERENCE: [Figma screenshot from Step 1]
  2. COMPOSE PREVIEW RESULT: [Preview screenshot from /tmp/implement-page-android/frame-{N}.png]

  Focus on the section that corresponds to frame '{frame_name}'
  (approximate Y position: {y_pos}dp, height: {height}dp from the Figma layout).

  Return your verdict using the visual mode output format.
")
```

Note: agmo:android-specialist is model-fixed to opus, so do NOT pass a model parameter.

**3c. Handle verdict:**

- **PASS** (score >= 7, no layout-breaking issues) → proceed to Step 4
- **FAIL** → dispatch `agmo:executor` with the android-specialist's issue list:
  ```
  Agent(subagent_type="agmo:executor", model="sonnet", prompt="
    Fix visual issues in Frame {N}: '{frame_name}'

    ## Issues from Visual Review
    {android_specialist_issues_list}

    ## Reference Images
    - Figma: [Figma screenshot]
    - Current Compose Preview: [Preview screenshot]

    Fix each listed issue. Focus on the specific Modifier properties, padding,
    color tokens, and Composable structures mentioned.
  ")
  ```
  Then re-capture and re-verify (back to 3a).

  Maximum 3 verification rounds per frame. After 3 failures, log remaining issues and continue to the next frame — do not block the entire page on one stubborn frame.

#### Step 4: Progress Report

After each frame, report to the user:

```
## Frame {N}/{total}: {frame_name} — {PASS|FAIL}
Verification: {PASS on attempt 1 | PASS on attempt 2 | FAIL after 3 attempts}
New Composables: {list or "none"}
{If FAIL: remaining issues summary}
```

### Phase 3: Final Verification & Completion

After all frames are implemented:

**1. Full-screen visual check:**

Capture the Figma page screenshot:

```
get_screenshot(fileKey="{fileKey}", nodeId="{pageNodeId}")
```

Capture the full Compose Preview:

```bash
bash scripts/capture-compose-preview.sh \
  --composable "com.example.ui.{PageScreen}_Preview" \
  --output /tmp/implement-page-android/full-page.png \
  --project-dir /path/to/project \
  --module app \
  --width 360 --height 640
```

Dispatch `agmo:android-specialist` to compare the full page:

```
Agent(subagent_type="agmo:android-specialist", prompt="
  ## Mode: visual
  ## Final Page Verification

  Compare full-page Figma design vs Compose Preview implementation.
  1. FIGMA: [full page screenshot]
  2. COMPOSE PREVIEW: [full page screenshot from /tmp/implement-page-android/full-page.png]

  Focus on:
  - Cross-frame spacing and transitions (gaps between sections)
  - Overall visual rhythm and consistency
  - Any missing sections

  Return your verdict using the visual mode output format.
  PASS threshold for final: score >= 8.
")
```

If NEEDS_POLISH, dispatch one final `agmo:executor` round for cross-frame spacing and padding fixes.

**2. Navigation integration (if multi-screen):**

If the Figma page contains multiple navigable screens (not just sections of a single scroll), dispatch `agmo:executor` to wire them into the project's navigation graph:

```
Agent(subagent_type="agmo:executor", model="sonnet", prompt="
  Wire implemented screens into the Navigation graph.

  Screens to connect:
  {list of screen composables from Component Registry}

  Follow the project's existing navigation pattern (NavHost/NavController).
  Do NOT create a new navigation setup if one already exists — integrate into it.
")
```

Skip this step if the page is a single scrollable screen composed of stacked sections.

### Phase 3.5: Responsive Verification (Optional)

If the user requested responsive verification or the Figma design includes tablet or foldable variants, dispatch `agmo:android-specialist` in responsive mode:

```
Agent(subagent_type="agmo:android-specialist", prompt="
  ## Mode: responsive

  Verify responsive behavior for {screen_name}.
  Preview capture script: scripts/capture-compose-preview.sh
  Project dir: {project_dir}
  Module: {module}

  Capture and evaluate at: Compact 360dp, Medium 600dp, Expanded 840dp.
")
```

**Completion report:**

```
## implement-page-android Complete

### Implemented Frames
- [x] Frame 1: TopAppBar — PASS
- [x] Frame 2: HeroSection — PASS (2nd attempt)
- [ ] Frame 3: ContentList — PARTIAL (differences logged)

### Component Registry (Final)
| Composable | Path | Parameters |
|------------|------|------------|
| AppButton | ui.components.AppButton | text: String, onClick: () -> Unit |
| FeatureCard | ui.components.FeatureCard | icon: ImageVector, title: String, description: String |

### Remaining Issues
- Frame 3: gradient brush mismatch in list item background
```

**Save to Obsidian:**

Dispatch `agmo:archivist` to save the implementation record:

```
Agent(subagent_type="agmo:archivist", model="haiku", prompt="
  Save implementation record to Obsidian vault.

  Use vault-save.sh with:
  --project '{project_name}'
  --type 'impl'
  --title 'Figma Page Android Implementation: {screen_name}'

  Content: the completion report above, including frame results,
  component registry, and remaining issues.
")
```

## Error Handling

| Situation | Action |
|-----------|--------|
| `get_metadata` fails | Verify Figma URL format, check Figma MCP connection |
| `get_design_context` truncated | Split query by child nodes via `get_metadata` |
| `build.gradle.kts` not found | Ask user to confirm project root path |
| Compose dependency missing | Alert user, abort skill |
| Compile error after 3 retries | Log compile errors, proceed to next frame |
| Preview capture fails (no library) | Show installation guide for Paparazzi/Roborazzi/Compose Preview Screenshot Testing. **Stop skill execution** — visual verification cannot proceed without screenshot capture. Resume after user confirms library setup. |
| Gradle build timeout | 120s threshold, alert user if exceeded |
| Visual verification fails 3 times | Log remaining issues, proceed to next frame |
| Theme/design system not found | Implement with default Material3 theme, alert user |
| No FRAME nodes in Figma | Suggest using implement-design skill instead |
