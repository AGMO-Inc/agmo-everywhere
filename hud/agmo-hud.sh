#!/usr/bin/env bash
# Agmo HUD — 2-line status display
# Called by Claude Code statusLine at regular intervals. Must be fast.

set -euo pipefail

AGMO_STATE_DIR="${AGMO_STATE_DIR:-${HOME}/.agmo/state}"

# --- Read stdin from Claude Code (contains context_window info) ---
STDIN_JSON=$(cat 2>/dev/null || echo "{}")

export HUD_STDIN="$STDIN_JSON"
PARSED=$(python3 -c "
import json, os, datetime, time
def fmt(ep):
  try:
    t = int(float(ep) - time.time())
    if t <= 0: return '0m'
    if t < 3600: return '%dm' % (t // 60)
    if t < 86400: return '%dh%dm' % (t // 3600, (t % 3600) // 60)
    return '%dd%dh' % (t // 86400, (t % 86400) // 3600)
  except Exception: return '?'
def load(p):
  try: return json.load(open(p)) or {}
  except Exception: return {}
try: d = json.loads(os.environ.get('HUD_STDIN') or '{}') or {}
except Exception: d = {}
if not isinstance(d, dict): d = {}
m = d.get('model') if isinstance(d.get('model'), dict) else {}
mid = m.get('id', '') or ''
st = load(os.path.expanduser('~/.claude/settings.json'))
ms = st.get('modelSettings') if isinstance(st.get('modelSettings'), dict) else {}
e = d.get('effort') if isinstance(d.get('effort'), dict) else {}
eff = e.get('level', '') or ''
if not eff and isinstance(ms.get(mid), dict): eff = ms[mid].get('effortLevel', '') or ''
if not eff: eff = st.get('effortLevel', '') or ''
cw = d.get('context_window') if isinstance(d.get('context_window'), dict) else {}
pct = cw.get('used_percentage')
ctx = ''
if pct is not None: ctx = str(int(round(pct)))
else:
  u = cw.get('current_usage') or {}
  tot = u.get('input_tokens', 0) + u.get('cache_creation_input_tokens', 0) + u.get('cache_read_input_tokens', 0)
  sz = cw.get('context_window_size', 0) or 0
  if sz > 0: ctx = str(int(round(tot / sz * 100)))
rl = d.get('rate_limits') if isinstance(d.get('rate_limits'), dict) else {}
def win(k):
  w = rl.get(k)
  if not isinstance(w, dict) or w.get('used_percentage') is None: return ['', '']
  return [str(int(round(w['used_percentage']))), fmt(w.get('resets_at'))]
print('|'.join([str(d.get('session_id', '') or ''), mid, str(m.get('display_name', '') or ''), eff, ctx] + win('five_hour') + win('seven_day')))
" 2>/dev/null || echo "||||||||")
IFS='|' read -r SESSION_ID MODEL_ID MODEL_NAME EFFORT CTX H5_PCT H5_RESET WK_PCT WK_RESET <<< "$PARSED"
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
  ACTIVE_AGENTS=$(STATE_DIR="$STATE_DIR" MODEL_ID="$MODEL_ID" EFFORT="$EFFORT" python3 -c "
import json, os
try:
  d = json.load(open(os.path.join(os.environ['STATE_DIR'], 'hud.json')))
  agents = d.get('agents', [])
  if not agents: print('-')
  else:
    try: st = json.load(open(os.path.expanduser('~/.claude/settings.json'))) or {}
    except Exception: st = {}
    ms = st.get('modelSettings') if isinstance(st.get('modelSettings'), dict) else {}
    main_eff = os.environ.get('EFFORT', '')
    mid = os.environ.get('MODEL_ID', '')
    fams = ('haiku', 'sonnet', 'opus', 'fable')
    def eff_for(alias):
      for k, v in ms.items():
        if alias in k and isinstance(v, dict) and v.get('effortLevel'):
          return v['effortLevel']
      return st.get('effortLevel', '') or ''
    counts = {}
    for a in agents:
      m = a.get('model', '') or ''
      if m:
        e = eff_for(m)
      else:
        m = next((f for f in fams if f in mid), '')
        e = main_eff
      key = a['name'] + (':' + m if m else '') + ('(' + e + ')' if m and e else '')
      counts[key] = counts.get(key, 0) + 1
    print(' '.join(k + '×' + str(v) if v > 1 else k for k, v in counts.items()))
except Exception: print('-')
" 2>/dev/null || echo "-")
fi

# --- Rate limit from Anthropic OAuth API ---

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
if [ -z "$H5_PCT" ] && [ -z "$WK_PCT" ]; then
  USAGE_PARSED=$(python3 "${SCRIPT_DIR}/usage-api.py" 2>/dev/null | python3 -c "
import json, sys
try:
  d = json.load(sys.stdin)
  if d.get('error'): raise ValueError
  print('|'.join(str(d.get(k, '')) for k in ('5h_pct', '5h_reset', 'wk_pct', 'wk_reset')))
except Exception: print('|||')
" 2>/dev/null || echo "|||")
  IFS='|' read -r H5_PCT H5_RESET WK_PCT WK_RESET <<< "$USAGE_PARSED"
fi

RATE_5H_COLORED=""
RATE_WK_COLORED=""
if [ -n "$H5_PCT" ]; then
  H5_COLOR=$(color_by_pct "$H5_PCT")
  RATE_5H_COLORED="${H5_COLOR}${H5_PCT}%${C_RESET}${C_DIM}(${H5_RESET})${C_RESET}"
fi
if [ -n "$WK_PCT" ]; then
  WK_COLOR=$(color_by_pct "$WK_PCT")
  RATE_WK_COLORED="${WK_COLOR}${WK_PCT}%${C_RESET}${C_DIM}(${WK_RESET})${C_RESET}"
fi

# --- Read plugin version & codex status from hud.json ---
PLUGIN_VERSION_PREFIX=""
_CODEX="false"
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
  LINE1="${PLUGIN_VERSION_PREFIX}🔋 5h:${RATE_5H_COLORED} wk:${RATE_WK_COLORED}"
elif [ -n "$RATE_WK_COLORED" ]; then
  LINE1="${PLUGIN_VERSION_PREFIX}🔋 wk:${RATE_WK_COLORED}"
elif [ -n "$RATE_5H_COLORED" ]; then
  LINE1="${PLUGIN_VERSION_PREFIX}🔋 5h:${RATE_5H_COLORED}"
else
  LINE1="${PLUGIN_VERSION_PREFIX}🔋 ${C_DIM}-${C_RESET}"
fi

CTX="${CTX:-0}"
CTX_COLOR=$(color_by_pct "$CTX")
LINE1="${LINE1}  📐 ctx:${CTX_COLOR}${CTX}%${C_RESET}"

# Line 2: 📂 project(branch)  [active_skill] ▸ agents
PROJECT_LABEL="${C_BLUE}📂 ${PROJECT}${C_RESET}"
if [ -n "$BRANCH" ]; then
  PROJECT_LABEL="${C_BLUE}📂 ${PROJECT}(${BRANCH})${C_RESET}"
fi

if [ -n "$ACTIVE_SKILL_NAME" ]; then
  LINE2="${PROJECT_LABEL}  🎯 [${C_MAGENTA}${ACTIVE_SKILL_NAME}${C_RESET}]  ⚡ ${C_YELLOW}${ACTIVE_AGENTS}${C_RESET}"
else
  ORCH_LABEL="🤖 ${C_MAGENTA}Agriman${C_RESET}"
  if [ -n "$MODEL_NAME" ] && [ -n "$EFFORT" ]; then
    ORCH_LABEL="🤖 ${C_MAGENTA}Agriman:${MODEL_NAME}(${EFFORT})${C_RESET}"
  elif [ -n "$MODEL_NAME" ]; then
    ORCH_LABEL="🤖 ${C_MAGENTA}Agriman:${MODEL_NAME}${C_RESET}"
  elif [ -n "$EFFORT" ]; then
    ORCH_LABEL="🤖 ${C_MAGENTA}Agriman:(${EFFORT})${C_RESET}"
  fi
  if [ "$ACTIVE_AGENTS" != "-" ] && [ -n "$ACTIVE_AGENTS" ]; then
    LINE2="${PROJECT_LABEL}  ${ORCH_LABEL}  ⚡ ${C_YELLOW}${ACTIVE_AGENTS}${C_RESET}"
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
