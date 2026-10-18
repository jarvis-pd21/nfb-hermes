#!/usr/bin/env bash
# NFB: start (or keep) this AI agent's Hermes gateway. Safe to run many times; the NFB Worker runs it on every wake.
#
# Input: ~/.nfb/agent.env, written by the NFB Worker (only this NFB's own, revocable credentials):
#   NFB_API, NFB_AID, NFB_INCARNATION, NFB_AGENT_KEY (MCP key), API_SERVER_KEY (Worker -> this computer),
#   NFB_BRAIN_PROVIDER = openrouter (default) | anthropic | workers-ai, NFB_BRAIN_MODEL, NFB_BRAIN_FALLBACK_MODELS (comma list),
#   NFB_BRAIN_BASE_URL (optional), NFB_BRAIN_KEY (this NFB's own sub-key, spend limit = its prepaid balance; or the owner's own key).
# The brain stays OFF until the owner has prepaid: the Worker only writes NFB_BRAIN_KEY then.
# Output: ~/.hermes/.env + ~/.hermes/config.yaml (rendered from nfb/config.yaml), the nfb-guard plugin, the gateway.
set -u
HH="${HERMES_HOME:-$HOME/.hermes}"; SRC="$(cd "$(dirname "$0")" && pwd)"; IN="${NFB_ENV:-$HOME/.nfb/agent.env}"
[ -f "$IN" ] || { echo "no $IN yet (the NFB Worker writes it at provision)"; exit 0; }
envget() { sed -n "s/^$1=//p" "$IN" | tail -1; }
NFB_API=$(envget NFB_API); AID=$(envget NFB_AID); KEY=$(envget NFB_BRAIN_KEY)
PROVIDER=$(envget NFB_BRAIN_PROVIDER); PROVIDER=${PROVIDER:-openrouter}
MODEL=$(envget NFB_BRAIN_MODEL); FALLBACK=$(envget NFB_BRAIN_FALLBACK_MODELS); BASE=$(envget NFB_BRAIN_BASE_URL)
stop() { pkill -f "nfb-gateway-loop" 2>/dev/null; pkill -f "hermes.* gateway run" 2>/dev/null; }
if [ -z "$KEY" ]; then echo "brain off: no brain key (prepaid balance is zero or not funded yet)"; stop; exit 0; fi
q() { printf '"%s"' "$1"; }
case "$PROVIDER" in
  openrouter) BASE=${BASE:-https://openrouter.ai/api/v1}; MODEL=${MODEL:-anthropic/claude-opus-5.5}; PROV=openrouter ;;
  anthropic)  BASE=${BASE:-https://api.anthropic.com};   MODEL=${MODEL:-claude-opus-5-5};          PROV=anthropic ;;
  workers-ai) MODEL=${MODEL:-@cf/meta/llama-3.3-70b-instruct-fp8-fast}; PROV=custom
              [ -n "$BASE" ] || { echo "workers-ai needs NFB_BRAIN_BASE_URL (the owner's own Cloudflare account)"; exit 1; } ;;
  *) echo "unknown NFB_BRAIN_PROVIDER=$PROVIDER"; exit 1 ;;
esac
MB="model:
  provider: $PROV
  default: $(q "$MODEL")"
[ "$PROV" = custom ] && MB="$MB
  base_url: $(q "$BASE")
  api_key: \"\${NFB_BRAIN_KEY}\""
if [ -n "$FALLBACK" ]; then  # model IDs on the SAME key: this NFB's own account, nothing shared
  MB="$MB

fallback_providers:"
  IFS=',' read -ra FBS <<< "$FALLBACK"
  for m in "${FBS[@]}"; do m="$(echo "$m" | xargs)"; [ -n "$m" ] || continue
    MB="$MB
  - provider: $PROV
    model: $(q "$m")
    base_url: $(q "$BASE")
    key_env: $(case "$PROV" in anthropic) echo ANTHROPIC_API_KEY;; openrouter) echo OPENROUTER_API_KEY;; *) echo NFB_BRAIN_KEY;; esac)"; done
fi
mkdir -p "$HH/plugins" "$HH/logs"; umask 077
{ grep -E '^(NFB_API|NFB_AID|NFB_INCARNATION|NFB_AGENT_KEY|NFB_BRAIN_KEY|API_SERVER_KEY)=' "$IN"
  echo "API_SERVER_ENABLED=true"
  echo "API_SERVER_HOST=$(envget API_SERVER_HOST | grep . || echo 0.0.0.0)"
  echo "API_SERVER_PORT=$(envget API_SERVER_PORT | grep . || echo 8642)"
  [ "$PROV" = anthropic ] && { echo "ANTHROPIC_API_KEY=$KEY"; echo "ANTHROPIC_BASE_URL=$BASE"; }
  [ "$PROV" = openrouter ] && { echo "OPENROUTER_API_KEY=$KEY"; echo "OPENROUTER_BASE_URL=$BASE"; }
} > "$HH/.env.new" && mv "$HH/.env.new" "$HH/.env"
python3 - "$SRC/config.yaml" "$HH/config.yaml" "${NFB_API:-https://api.nonfungiblebot.com}" "$AID" "$MB" <<'PY'
import os, sys; src, dst, api, aid, mb = sys.argv[1:]
t = open(src).read().replace("__MODEL_BLOCK__", mb).replace("__NFB_API__", api).replace("__AID__", aid)
open(dst + ".new", "w").write(t); os.replace(dst + ".new", dst)
PY
rm -rf "$HH/plugins/nfb-guard" && cp -r "$SRC/plugins/nfb-guard" "$HH/plugins/nfb-guard"
[ -d "$SRC/skills" ] && mkdir -p "$HH/skills" && cp -r "$SRC/skills/." "$HH/skills/"
mkdir -p "$HOME/.local/bin" && ln -sf "$SRC/bin/deep-work" "$HOME/.local/bin/deep-work"
HERMES="${HERMES_BIN:-$(command -v hermes || echo "$HOME/.local/bin/hermes")}"
"$HERMES" plugins enable nfb-guard >/dev/null 2>&1 || true
if [ "${1:-}" = "--restart" ]; then stop; sleep 1; fi
if pgrep -f "hermes.* gateway run" >/dev/null; then echo "gateway already up"; exit 0; fi
# keep-alive loop (named so stop() finds it): the gateway exits 75 to ask for a restart; anything else restarts after 2 s
setsid nohup bash -c "exec -a nfb-gateway-loop bash -c 'while [ -f \"$IN\" ]; do \"$HERMES\" gateway run >>\"$HH/logs/nfb-gateway.log\" 2>&1; sleep 2; done'" >/dev/null 2>&1 </dev/null &
echo "gateway starting"
