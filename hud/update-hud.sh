#!/usr/bin/env bash
# Update HUD state file
# Usage:
#   update-hud.sh skill <name> <category>     — set active skill
#   update-hud.sh agent-add <name> <model>    — add active agent
#   update-hud.sh agent-clear                 — clear all agents
#   update-hud.sh ctx <percent>               — set context usage
#   update-hud.sh clear                       — reset all state

set -euo pipefail

AGMO_STATE_DIR="${AGMO_STATE_DIR:-${HOME}/.agmo/state}"
# STATE_FILE can be overridden by caller for session isolation
STATE_FILE="${STATE_FILE:-${AGMO_STATE_DIR}/hud.json}"
mkdir -p "$(dirname "$STATE_FILE")"

# Initialize state file if missing
if [ ! -f "$STATE_FILE" ]; then
  echo '{"skill":"","category":"","agents":[],"ctx_pct":"","active_skill":null,"plugin_version":""}' > "$STATE_FILE"
fi

ACTION="${1:-}"
shift || true

case "$ACTION" in
  skill)
    NAME="${1:-}"
    CATEGORY="${2:-}"
    export STATE_FILE NAME CATEGORY
    python3 -c "
import json, os
with open(os.environ['STATE_FILE']) as f:
    d=json.load(f)
d['skill']=os.environ['NAME']
d['category']=os.environ['CATEGORY']
with open(os.environ['STATE_FILE'],'w') as f:
    json.dump(d,f)
" 2>/dev/null
    ;;
  agent-add)
    NAME="${1:-}"
    MODEL="${2:-}"
    export STATE_FILE NAME MODEL
    python3 -c "
import json, os
with open(os.environ['STATE_FILE']) as f:
    d=json.load(f)
d.setdefault('agents',[]).append({'name':os.environ['NAME'],'model':os.environ['MODEL']})
with open(os.environ['STATE_FILE'],'w') as f:
    json.dump(d,f)
" 2>/dev/null
    ;;
  agent-clear)
    export STATE_FILE
    python3 -c "
import json, os
with open(os.environ['STATE_FILE']) as f:
    d=json.load(f)
d['agents']=[]
with open(os.environ['STATE_FILE'],'w') as f:
    json.dump(d,f)
" 2>/dev/null
    ;;
  ctx)
    PCT="${1:-}"
    export STATE_FILE PCT
    python3 -c "
import json, os
with open(os.environ['STATE_FILE']) as f:
    d=json.load(f)
d['ctx_pct']=os.environ['PCT']
with open(os.environ['STATE_FILE'],'w') as f:
    json.dump(d,f)
" 2>/dev/null
    ;;
  clear)
    echo '{"skill":"","category":"","agents":[],"ctx_pct":"","active_skill":null,"plugin_version":""}' > "$STATE_FILE"
    ;;
  *)
    echo "Usage: update-hud.sh {skill|agent-add|agent-clear|ctx|clear} [args...]" >&2
    exit 1
    ;;
esac
