#!/usr/bin/env bash
# Agmo HUD — 2-line status display
# Called by Claude Code statusLine at regular intervals. Must be fast.

set -euo pipefail

AGMO_STATE_DIR="${AGMO_STATE_DIR:-${HOME}/.agmo/state}"

# --- Read stdin from Claude Code (contains context_window info) ---
STDIN_JSON=$(cat 2>/dev/null || echo "{}")

# Extract session_id for session-isolated state
SESSION_ID=$(echo "$STDIN_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || echo "")
if [ -n "$SESSION_ID" ]; then
  STATE_DIR="${AGMO_STATE_DIR}/sessions/${SESSION_ID}"
else
  STATE_DIR="${AGMO_STATE_DIR}"
fi

# --- Project name (parent/project) & branch ---
PROJECT=""
BRANCH=""
if git rev-parse --is-inside-work-tree &>/dev/null; then
  _toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  PROJECT="$(basename "$(dirname "$_toplevel")")/$(basename "$_toplevel")"
  BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
else
  PROJECT="$(basename "$(dirname "$PWD")")/$(basename "$PWD")"
fi

# --- Active skill & agents (from state file) ---
ACTIVE_SKILL="-"
ACTIVE_AGENTS="-"
ACTIVE_SKILL_NAME=""
if [ -f "${STATE_DIR}/hud.json" ]; then
  ACTIVE_SKILL=$(python3 -c "
import json,sys
try:
  d=json.load(open('${STATE_DIR}/hud.json'))
  s=d.get('skill','')
  print(s if s else '-')
except Exception: print('-')
" 2>/dev/null || echo "-")
  ACTIVE_SKILL_NAME=$(python3 -c "
import json
try:
  d=json.load(open('${STATE_DIR}/hud.json'))
  s=d.get('active_skill','')
  print(s if s else '')
except Exception: print('')
" 2>/dev/null || echo "")
  ACTIVE_AGENTS=$(python3 -c "
import json
try:
  d=json.load(open('${STATE_DIR}/hud.json'))
  agents=d.get('agents',[])
  if not agents: print('-')
  else:
    counts={}
    for a in agents:
      m=a.get('model','')
      key=f\"{a['name']}:{m}\" if m else a['name']
      counts[key]=counts.get(key,0)+1
    parts=[f'{k}×{v}' if v>1 else k for k,v in counts.items()]
    print(' '.join(parts))
except Exception: print('-')
" 2>/dev/null || echo "-")
fi

# --- Rate limit from Anthropic OAuth API ---
RATE_5H=""
RATE_WK=""
CTX=""

# ANSI colors
C_GREEN=$'\x1b[32m'
C_YELLOW=$'\x1b[33m'
C_RED=$'\x1b[31m'
C_DIM=$'\x1b[2m'
C_RESET=$'\x1b[0m'
C_CYAN=$'\x1b[36m'
C_BLUE=$'\x1b[94m'
C_MAGENTA=$'\x1b[35m'
C_BOLD_GREEN=$'\x1b[1;32m'

color_by_pct() {
  local pct=$1
  if [ "$pct" -ge 75 ]; then echo "$C_RED"
  elif [ "$pct" -ge 50 ]; then echo "$C_YELLOW"
  else echo "$C_GREEN"
  fi
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USAGE_JSON=$(python3 "${SCRIPT_DIR}/usage-api.py" 2>/dev/null || echo '{"error":true}')

if echo "$USAGE_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(1 if d.get('error') else 0)" 2>/dev/null; then
  RATE_5H=$(echo "$USAGE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f\"{d['5h_pct']}|{d['5h_reset']}\")
" 2>/dev/null || echo "")
  RATE_WK=$(echo "$USAGE_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f\"{d['wk_pct']}|{d['wk_reset']}\")
" 2>/dev/null || echo "")
fi

# Apply colors to rate limit values
RATE_5H_COLORED=""
RATE_WK_COLORED=""
if [ -n "$RATE_5H" ]; then
  H5_PCT=$(echo "$RATE_5H" | cut -d'|' -f1)
  H5_RESET=$(echo "$RATE_5H" | cut -d'|' -f2)
  H5_COLOR=$(color_by_pct "$H5_PCT")
  RATE_5H_COLORED="${H5_COLOR}${H5_PCT}%${C_RESET}${C_DIM}(${H5_RESET})${C_RESET}"
fi
if [ -n "$RATE_WK" ]; then
  WK_PCT=$(echo "$RATE_WK" | cut -d'|' -f1)
  WK_RESET=$(echo "$RATE_WK" | cut -d'|' -f2)
  WK_COLOR=$(color_by_pct "$WK_PCT")
  RATE_WK_COLORED="${WK_COLOR}${WK_PCT}%${C_RESET}${C_DIM}(${WK_RESET})${C_RESET}"
fi

# Context usage from Claude Code stdin
CTX=$(echo "$STDIN_JSON" | python3 -c "
import json,sys,math
try:
  d=json.load(sys.stdin)
  cw=d.get('context_window',{})
  pct=cw.get('used_percentage')
  if pct is not None:
    print(int(round(pct)))
  else:
    usage=cw.get('current_usage',{})
    total=usage.get('input_tokens',0)+usage.get('cache_creation_input_tokens',0)+usage.get('cache_read_input_tokens',0)
    size=cw.get('context_window_size',0)
    if size>0: print(int(round(total/size*100)))
except Exception: pass
" 2>/dev/null || echo "")

# --- Read plugin version & codex status from hud.json ---
PLUGIN_VERSION_PREFIX=""
if [ -f "${STATE_DIR}/hud.json" ]; then
  _PV=$(STATE_DIR="$STATE_DIR" python3 -c "
import json, os
try:
  d = json.load(open(os.path.join(os.environ['STATE_DIR'], 'hud.json')))
  v = d.get('plugin_version', '')
  print(v if v else '')
except Exception: print('')
" 2>/dev/null || echo "")
  _CODEX=$(STATE_DIR="$STATE_DIR" python3 -c "
import json, os
try:
  d = json.load(open(os.path.join(os.environ['STATE_DIR'], 'hud.json')))
  print('true' if d.get('codex') else 'false')
except Exception: print('false')
" 2>/dev/null || echo "false")
  if [ -n "$_PV" ]; then
    PLUGIN_VERSION_PREFIX="${C_CYAN}[agmo:${_PV}]${C_RESET} "
  fi
fi

# --- Build output ---
LINE1=""
LINE2=""

# Line 1: ⏱ rate limits | 📐 ctx | 📂 project
if [ -n "$RATE_5H_COLORED" ] && [ -n "$RATE_WK_COLORED" ]; then
  LINE1="${PLUGIN_VERSION_PREFIX}⏱ 5h:${RATE_5H_COLORED} wk:${RATE_WK_COLORED}"
else
  LINE1="${PLUGIN_VERSION_PREFIX}⏱ ${C_DIM}-${C_RESET}"
fi

CTX="${CTX:-0}"
CTX_COLOR=$(color_by_pct "$CTX")
LINE1="${LINE1}  📐 ctx:${CTX_COLOR}${CTX}%${C_RESET}"

# Line 2: 📂 project(branch)  [active_skill] ▸ agents
PROJECT_LABEL="${C_BLUE}📂 ${PROJECT}${C_RESET}"
if [ -n "$BRANCH" ]; then
  PROJECT_LABEL="${C_BLUE}📂 ${PROJECT}(${BRANCH})${C_RESET}"
fi

# Read model and effort from stdin JSON and settings
MODEL_NAME=$(echo "$STDIN_JSON" | python3 -c "
import json,sys
try:
  d=json.load(sys.stdin)
  m=d.get('model',{})
  print(m.get('display_name','') if isinstance(m,dict) else '')
except Exception: print('')
" 2>/dev/null || echo "")

EFFORT=$(python3 -c "
import json
try:
  d=json.load(open('${HOME}/.claude/settings.json'))
  print(d.get('effortLevel',''))
except Exception: print('')
" 2>/dev/null || echo "")

if [ -n "$ACTIVE_SKILL_NAME" ]; then
  LINE2="${PROJECT_LABEL}  [${C_MAGENTA}${ACTIVE_SKILL_NAME}${C_RESET}]  ${C_YELLOW}▸ ${ACTIVE_AGENTS}${C_RESET}"
else
  ORCH_LABEL="${C_MAGENTA}Agriman${C_RESET}"
  if [ -n "$MODEL_NAME" ] && [ -n "$EFFORT" ]; then
    ORCH_LABEL="${C_MAGENTA}Agriman:${MODEL_NAME}(${EFFORT})${C_RESET}"
  elif [ -n "$MODEL_NAME" ]; then
    ORCH_LABEL="${C_MAGENTA}Agriman:${MODEL_NAME}${C_RESET}"
  elif [ -n "$EFFORT" ]; then
    ORCH_LABEL="${C_MAGENTA}Agriman:(${EFFORT})${C_RESET}"
  fi
  if [ "$ACTIVE_AGENTS" != "-" ] && [ -n "$ACTIVE_AGENTS" ]; then
    LINE2="${PROJECT_LABEL}  ${ORCH_LABEL}  ${C_YELLOW}▸ ${ACTIVE_AGENTS}${C_RESET}"
  else
    LINE2="${PROJECT_LABEL}  ${ORCH_LABEL}"
  fi
fi

# Append codex status to Line 1
if [ "$_CODEX" = "true" ]; then
  LINE1="${LINE1}  ${C_BOLD_GREEN}codex:on${C_RESET}"
else
  LINE1="${LINE1}  ${C_DIM}codex:off${C_RESET}"
fi

echo "${LINE1}"
echo "${LINE2}"
