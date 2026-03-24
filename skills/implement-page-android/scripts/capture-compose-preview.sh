#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# capture-compose-preview.sh
# Captures a Compose @Preview composable as a PNG using an available
# screenshot testing library (Paparazzi, Roborazzi, or Compose Preview
# Screenshot Testing). Falls back with instructions if none is detected.
# ---------------------------------------------------------------------------

# --- Defaults ---------------------------------------------------------------
COMPOSABLE=""
OUTPUT=""
PROJECT_DIR="."
MODULE="app"
WIDTH="360"
HEIGHT="640"

# --- Usage ------------------------------------------------------------------
usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") --composable <fqn> --output <path> [options]

Required:
  --composable <fqn>      Fully qualified name of the @Preview composable
                          (e.g. com.example.ui.HomeScreenPreview)
  --output <path>         Output PNG file path

Optional:
  --project-dir <dir>     Android project root directory (default: .)
  --module <name>         Gradle module name (default: app)
  --width <dp>            Preview width in dp (default: 360)
  --height <dp>           Preview height in dp (default: 640)
EOF
  exit 1
}

# --- Parse arguments --------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --composable)
      COMPOSABLE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$2"
      shift 2
      ;;
    --module)
      MODULE="$2"
      shift 2
      ;;
    --width)
      WIDTH="$2"
      shift 2
      ;;
    --height)
      HEIGHT="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage
      ;;
  esac
done

# --- Validate required arguments --------------------------------------------
if [[ -z "$COMPOSABLE" ]]; then
  echo "ERROR: --composable is required" >&2
  usage
fi

if [[ -z "$OUTPUT" ]]; then
  echo "ERROR: --output is required" >&2
  usage
fi

# --- Create output directory ------------------------------------------------
mkdir -p "$(dirname "$OUTPUT")"

# --- Resolve project dir and build file path --------------------------------
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
BUILD_GRADLE="$PROJECT_DIR/$MODULE/build.gradle.kts"

# Extract simple class name from fully qualified name (last segment)
SIMPLE_NAME="${COMPOSABLE##*.}"

# --- Detection and execution ------------------------------------------------

# (a) Paparazzi
if [[ -f "$BUILD_GRADLE" ]] && grep -qE 'app\.cash\.paparazzi|paparazzi' "$BUILD_GRADLE"; then
  echo "INFO: Paparazzi detected. Running recordPaparazziDebug..." >&2

  (cd "$PROJECT_DIR" && ./gradlew ":${MODULE}:recordPaparazziDebug" \
    --tests "*${SIMPLE_NAME}*") >&2

  # Locate the snapshot PNG written by Paparazzi
  SNAPSHOT_DIR="$PROJECT_DIR/$MODULE/src/test/snapshots/images"
  SNAPSHOT_FILE="$(find "$SNAPSHOT_DIR" -name "*${SIMPLE_NAME}*" -type f | head -n 1)"

  if [[ -z "$SNAPSHOT_FILE" ]]; then
    echo "ERROR: Paparazzi snapshot not found under $SNAPSHOT_DIR" >&2
    exit 1
  fi

  cp "$SNAPSHOT_FILE" "$OUTPUT"
  echo "$OUTPUT"
  exit 0
fi

# (b) Roborazzi
if [[ -f "$BUILD_GRADLE" ]] && grep -qE 'io\.github\.takahirom\.roborazzi|roborazzi' "$BUILD_GRADLE"; then
  echo "INFO: Roborazzi detected. Running recordRoborazziDebug..." >&2

  (cd "$PROJECT_DIR" && ./gradlew ":${MODULE}:recordRoborazziDebug" \
    --tests "*${SIMPLE_NAME}*") >&2

  # Locate the screenshot PNG written by Roborazzi
  ROBORAZZI_DIR="$PROJECT_DIR/$MODULE/build/outputs/roborazzi"
  ROBORAZZI_FILE="$(find "$ROBORAZZI_DIR" -name "*${SIMPLE_NAME}*" -type f | head -n 1)"

  if [[ -z "$ROBORAZZI_FILE" ]]; then
    echo "ERROR: Roborazzi screenshot not found under $ROBORAZZI_DIR" >&2
    exit 1
  fi

  cp "$ROBORAZZI_FILE" "$OUTPUT"
  echo "$OUTPUT"
  exit 0
fi

# (c) Compose Preview Screenshot Testing
SCREENSHOT_TEST_SRC="$PROJECT_DIR/$MODULE/src/screenshotTest"
if [[ -d "$SCREENSHOT_TEST_SRC" ]]; then
  echo "INFO: Compose Preview Screenshot Testing detected. Running updateDebugScreenshotTest..." >&2

  (cd "$PROJECT_DIR" && ./gradlew ":${MODULE}:updateDebugScreenshotTest" \
    --tests "*${SIMPLE_NAME}*") >&2

  # Locate the reference PNG produced by the plugin
  CPST_DIR="$PROJECT_DIR/$MODULE/src/screenshotTest/reference"
  CPST_FILE="$(find "$CPST_DIR" -name "*${SIMPLE_NAME}*" -type f | head -n 1)"

  if [[ -z "$CPST_FILE" ]]; then
    echo "ERROR: Screenshot not found under $CPST_DIR" >&2
    exit 1
  fi

  cp "$CPST_FILE" "$OUTPUT"
  echo "$OUTPUT"
  exit 0
fi

# (d) Fallback — no library detected → STOP
cat >&2 <<'EOF'
ERROR: No screenshot testing library detected.

Visual verification requires one of these libraries. Install before proceeding:

  1. Paparazzi (recommended — JVM-only, no emulator needed):
     https://github.com/cashapp/paparazzi

  2. Roborazzi (Robolectric-based):
     https://github.com/takahirom/roborazzi

  3. Compose Preview Screenshot Testing (official Android):
     https://developer.android.com/studio/preview/compose-screenshot-testing

The implement-page-android skill cannot proceed without screenshot capture.
Please install a library and re-run the skill.
EOF
exit 1
