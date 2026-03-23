#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  B2B SDR Agent — One-Click Deploy
#  Usage: ./deploy.sh <client-name>
#  Example: ./deploy.sh acme-corp
# ═══════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*" >&2; }
info()  { echo -e "${CYAN}[→]${NC} $*"; }

# ─── Args ─────────────────────────────────────────────────
if [ $# -lt 1 ]; then
  echo "Usage: $0 <client-name> [--dry-run]"
  exit 1
fi

CLIENT_NAME="$1"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
DRY_RUN=false
[ "${2:-}" = "--dry-run" ] && DRY_RUN=true

if [ ! -f "$CONFIG_FILE" ]; then
  err "Missing config: $CONFIG_FILE"
  echo "Run: cp config.sh.example config.sh && edit config.sh"
  exit 1
fi

# ─── Load Config ──────────────────────────────────────────
source "$CONFIG_FILE"

missing=()
[ -z "$SERVER_HOST" ] && missing+=("SERVER_HOST")
[ -z "$PRIMARY_API_KEY" ] && [ -z "$FALLBACK_API_KEY" ] && missing+=("At least one model API key")
if [ ${#missing[@]} -gt 0 ]; then
  err "Missing required config: ${missing[*]}"
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  B2B SDR Agent Deploy — $CLIENT_NAME"
echo "═══════════════════════════════════════════════════════════"
echo ""
info "Server: ${SERVER_USER}@${SERVER_HOST}:${SERVER_PORT:-22}"
info "Primary Model: ${PRIMARY_PROVIDER}/${PRIMARY_MODEL_ID}"
info "Gateway Port: ${GATEWAY_PORT}"
echo ""

if [ "$DRY_RUN" = true ]; then
  warn "Dry-run mode — no actual changes will be made"
fi

# ─── SSH Setup ────────────────────────────────────────────
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
[ -n "${SSH_KEY:-}" ] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

SSHPASS_PREFIX=""
if [ -n "${SSH_PASS:-}" ]; then
  if ! command -v sshpass &>/dev/null; then
    err "sshpass required for password auth: brew install sshpass / apt install sshpass"
    exit 1
  fi
  python3 -c "
import sys
with open('/tmp/.sdr-deploy-pw', 'w') as f:
    f.write(sys.argv[1])
" "$SSH_PASS"
  SSHPASS_PREFIX="sshpass -f /tmp/.sdr-deploy-pw"
  SSH_OPTS="$SSH_OPTS -o PubkeyAuthentication=no"
fi

SSH_CMD="$SSHPASS_PREFIX ssh $SSH_OPTS -p ${SERVER_PORT:-22} ${SERVER_USER}@${SERVER_HOST}"
SCP_CMD="$SSHPASS_PREFIX scp $SSH_OPTS -P ${SERVER_PORT:-22}"

cleanup_pw() { rm -f /tmp/.sdr-deploy-pw; }
trap cleanup_pw EXIT

remote() {
  if [ "$DRY_RUN" = true ]; then echo "[dry-run] ssh: $*"
  else $SSH_CMD "$@"; fi
}

remote_upload() {
  local src="$1" dst="$2"
  if [ "$DRY_RUN" = true ]; then echo "[dry-run] scp: $src → $dst"
  else $SCP_CMD -r "$src" "${SERVER_USER}@${SERVER_HOST}:$dst"; fi
}

# ─── Step 1: Test Connection ─────────────────────────────
info "Step 1/7: Testing SSH connection..."
if ! remote "echo ok" > /dev/null 2>&1; then
  err "Cannot connect to ${SERVER_HOST}"
  exit 1
fi
log "SSH connection successful"

# ─── Step 2: Install OpenClaw ─────────────────────────────
info "Step 2/7: Checking OpenClaw..."
OPENCLAW_INSTALLED=$(remote "which openclaw 2>/dev/null && openclaw --version 2>/dev/null || echo 'NOT_INSTALLED'")

if echo "$OPENCLAW_INSTALLED" | grep -q "NOT_INSTALLED"; then
  if [ "$INSTALL_OPENCLAW" = true ]; then
    info "  Installing OpenClaw..."
    remote "npm install -g openclaw 2>&1 | tail -3"
    log "  OpenClaw installed"
  else
    err "OpenClaw not installed and INSTALL_OPENCLAW=false"
    exit 1
  fi
else
  log "OpenClaw already installed: $(echo "$OPENCLAW_INSTALLED" | tail -1)"
fi

# ─── Step 3: Check Node.js ───────────────────────────────
info "Step 3/7: Checking Node.js..."
NODE_CHECK=$(remote "node --version 2>/dev/null || echo 'NOT_INSTALLED'")

if echo "$NODE_CHECK" | grep -q "NOT_INSTALLED"; then
  info "  Installing Node.js..."
  remote "curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y nodejs"
  log "  Node.js installed"
else
  log "Node.js installed: $NODE_CHECK"
fi

# ─── Step 4: Generate openclaw.json ──────────────────────
info "Step 4/7: Generating config..."
bash "$SCRIPT_DIR/generate-config.sh" "$SCRIPT_DIR"
log "openclaw.json generated"

GATEWAY_TOKEN=$(grep -o '"token": "[^"]*"' "$SCRIPT_DIR/openclaw.json" | tail -1 | cut -d'"' -f4)

# ─── Step 5: Deploy Files ────────────────────────────────
info "Step 5/7: Deploying files..."

remote "mkdir -p /root/.openclaw/{workspace,memory,skills,delivery-queue}"

remote_upload "$SCRIPT_DIR/openclaw.json" "/root/.openclaw/openclaw.json"
log "  openclaw.json deployed"

# Upload workspace MD files
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")/workspace"
for md in IDENTITY.md SOUL.md USER.md AGENTS.md MEMORY.md HEARTBEAT.md TOOLS.md; do
  if [ -f "$WORKSPACE_DIR/$md" ]; then
    remote_upload "$WORKSPACE_DIR/$md" "/root/.openclaw/workspace/$md"
    log "  $md deployed"
  fi
done

# ─── Step 6: Start Gateway ───────────────────────────────
info "Step 6/7: Starting Gateway..."

remote "mkdir -p /root/.config/systemd/user"
remote "cat > /root/.config/systemd/user/openclaw-gateway.service << 'EOF'
[Unit]
Description=OpenClaw Gateway
After=network-online.target

[Service]
ExecStart=/usr/bin/openclaw gateway --port $GATEWAY_PORT
Restart=always
RestartSec=5
Environment=HOME=/root
Environment=PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
EOF"

if [ "$AUTO_START" = true ]; then
  remote "systemctl --user daemon-reload && systemctl --user enable openclaw-gateway && systemctl --user restart openclaw-gateway"
  sleep 3
  GW_STATUS=$(remote "systemctl --user is-active openclaw-gateway 2>/dev/null || echo 'failed'")
  if [ "$GW_STATUS" = "active" ]; then
    log "Gateway started (port $GATEWAY_PORT)"
  else
    warn "Gateway may have failed to start. Check: ssh ${SERVER_USER}@${SERVER_HOST} journalctl --user -u openclaw-gateway -n 20"
  fi
fi

# ─── Step 7: Install Skills ──────────────────────────────
info "Step 7/7: Installing Skills (profile: ${SKILL_PROFILE:-b2b_trade})..."

source "$SCRIPT_DIR/skill-profiles.sh"
SKILL_LIST=$(get_skills_for_profile "${SKILL_PROFILE:-b2b_trade}")

if [ -n "${EXTRA_SKILLS:-}" ]; then
  IFS=',' read -ra EXTRA_ARR <<< "$EXTRA_SKILLS"
  SKILL_LIST="$SKILL_LIST ${EXTRA_ARR[*]}"
fi

SKILL_LIST=$(echo "$SKILL_LIST" | tr ' ' '\n' | sort -u | tr '\n' ' ')
SKILL_COUNT=$(echo "$SKILL_LIST" | wc -w | tr -d ' ')

if [ -n "$SKILL_LIST" ] && [ "$SKILL_COUNT" -gt 0 ]; then
  info "  $SKILL_COUNT skills to install"
  for skill in $SKILL_LIST; do
    remote "cd /root/.openclaw/workspace/skills && clawhub install $skill --force --no-input 2>&1 | tail -1" 2>/dev/null || true
  done
  log "  Skills installed"
fi

# ─── Done ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo -e "  ${GREEN}✅ Deploy Complete: $CLIENT_NAME${NC}"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Server:           ${SERVER_HOST}"
echo "  Gateway:          ws://${SERVER_HOST}:${GATEWAY_PORT}"
echo "  Gateway Token:    ${GATEWAY_TOKEN}"
echo ""
echo "  WhatsApp:         $( [ "$WHATSAPP_ENABLED" = true ] && echo 'Enabled' || echo 'Disabled' )"
echo "  Telegram:         $( [ "$TELEGRAM_ENABLED" = true ] && echo 'Enabled' || echo 'Disabled' )"
echo "  Skills:           ${SKILL_PROFILE:-b2b_trade} ($SKILL_COUNT skills)"
echo ""
echo "  Commands:"
echo "    Status:  ssh ${SERVER_USER}@${SERVER_HOST} systemctl --user status openclaw-gateway"
echo "    Logs:    ssh ${SERVER_USER}@${SERVER_HOST} journalctl --user -u openclaw-gateway -f"
echo "    Restart: ssh ${SERVER_USER}@${SERVER_HOST} systemctl --user restart openclaw-gateway"
echo ""
