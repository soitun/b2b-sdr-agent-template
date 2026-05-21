#!/usr/bin/env bash
# WhatsApp Legacy Account Onboarding — Interactive Bootstrap
#
# Run this once at the start of every customer delivery. It walks through:
#   1. Environment check (Python, deps, API key)
#   2. Salt generation + secure storage
#   3. Scenario detection (Business API / Business App / personal; iOS / Android)
#   4. Extraction-path-specific guidance
#   5. Parser + extractor execution
#   6. Verification report
#
# Designed to be RE-RUNNABLE. Each step skips if already done.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATE_FILE="${PROJECT_DIR}/.bootstrap-state"
LOG_FILE="${PROJECT_DIR}/bootstrap.log"

# ---- Output helpers ----------------------------------------------------------

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

say()  { printf "%b\n" "$*" | tee -a "${LOG_FILE}"; }
info() { say "${BLUE}ℹ${NC}  $*"; }
ok()   { say "${GREEN}✓${NC}  $*"; }
warn() { say "${YELLOW}⚠${NC}  $*"; }
err()  { say "${RED}✗${NC}  $*"; }

ask() {
    local prompt="$1" varname="$2"
    if [[ -n "${!varname:-}" ]]; then return 0; fi
    read -r -p "$(printf "%b" "${YELLOW}?${NC}  ${prompt}: ")" answer
    printf -v "${varname}" '%s' "${answer}"
    printf '%s=%q\n' "${varname}" "${answer}" >> "${STATE_FILE}"
}

ask_choice() {
    local prompt="$1" varname="$2"; shift 2
    if [[ -n "${!varname:-}" ]]; then return 0; fi
    say ""
    say "${YELLOW}?${NC}  ${prompt}"
    local i=1
    for opt in "$@"; do
        say "    [${i}] ${opt}"
        ((i++))
    done
    local idx
    read -r -p "$(printf "%b" "    ${YELLOW}>${NC} 选择: ")" idx
    local chosen="${!idx}"
    printf -v "${varname}" '%s' "${chosen}"
    printf '%s=%q\n' "${varname}" "${chosen}" >> "${STATE_FILE}"
}

# Load previous state if present
if [[ -f "${STATE_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${STATE_FILE}"
    info "Resuming from existing state: ${STATE_FILE}"
fi

mkdir -p "$(dirname "${LOG_FILE}")"
: > "${LOG_FILE}"

say ""
say "============================================================"
say "  WhatsApp Legacy Account Onboarding — Bootstrap"
say "============================================================"
say ""

# ---- Step 1: environment -----------------------------------------------------

info "Step 1/6 — Environment check"

if ! command -v python3 >/dev/null 2>&1; then
    err "python3 not found. Install Python 3.11+ first."
    exit 1
fi
PY_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
if [[ "$(printf '%s\n3.11\n' "${PY_VERSION}" | sort -V | head -1)" != "3.11" ]]; then
    warn "Python ${PY_VERSION} detected; 3.11+ recommended."
fi
ok "Python ${PY_VERSION}"

if ! python3 -c 'import anthropic, yaml' >/dev/null 2>&1; then
    info "Installing Python dependencies..."
    python3 -m pip install -q -r "${SCRIPT_DIR}/requirements.txt"
fi
ok "anthropic + PyYAML installed"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    warn "ANTHROPIC_API_KEY not set in environment."
    ask "Paste your Anthropic API key (starts with sk-ant-)" ANTHROPIC_API_KEY
    export ANTHROPIC_API_KEY
fi
ok "ANTHROPIC_API_KEY set"

# ---- Step 2: salt ------------------------------------------------------------

info "Step 2/6 — PII salt"

SECRETS_DIR="${HOME}/.secrets"
SALT_FILE="${SECRETS_DIR}/whatsapp-onboarding-salt.txt"
mkdir -p "${SECRETS_DIR}"
chmod 700 "${SECRETS_DIR}"

if [[ -f "${SALT_FILE}" ]]; then
    EXPORT_SALT="$(cat "${SALT_FILE}")"
    ok "Reusing existing salt at ${SALT_FILE}"
else
    EXPORT_SALT="$(openssl rand -hex 16)"
    echo "${EXPORT_SALT}" > "${SALT_FILE}"
    chmod 600 "${SALT_FILE}"
    ok "Generated new salt at ${SALT_FILE}"
    warn "BACK THIS UP to your password manager NOW. Losing it = customer hashes become unreconcilable."
    read -r -p "    Press Enter once you've backed it up..."
fi
export EXPORT_SALT

# ---- Step 3: scenario detection ----------------------------------------------

info "Step 3/6 — Customer scenario"

ask_choice "What kind of WhatsApp account does the customer use?" ACCOUNT_TYPE \
    "Business API (Cloud API or on-prem)" \
    "Business App (the phone app for businesses)" \
    "Personal account"

if [[ "${ACCOUNT_TYPE}" == "Business API (Cloud API or on-prem)" ]]; then
    warn "Business API has ZERO historical data via webhook."
    warn "Switching to seed-mode: profiles built from CRM/email + future webhook capture."
    DELIVERY_PATH="A"
else
    ask_choice "Customer's phone OS?" PHONE_OS "iOS" "Android"
    if [[ "${ACCOUNT_TYPE}" == *"Personal"* ]]; then DELIVERY_PATH="C"; else DELIVERY_PATH="B"; fi
fi
ok "Delivery path = ${DELIVERY_PATH}"

# ---- Step 4: extraction guidance --------------------------------------------

info "Step 4/6 — Extraction guidance"

EXPORTS_DIR="${PROJECT_DIR}/exports"
mkdir -p "${EXPORTS_DIR}"

case "${DELIVERY_PATH}" in
    A)
        say ""
        say "    Path A — Business API customer."
        say "    1. Configure webhook to log to /var/log/wa-webhook/*.jsonl on customer's gateway."
        say "    2. Have the salesperson seed Layer A profiles in:"
        say "         ${PROJECT_DIR}/seeds/customer_profile_seed.yaml"
        say "    3. Re-run this script after 30+ days of webhook capture."
        say ""
        ask "Press Enter to continue (Layer A only run today)..." _CONFIRM
        ;;
    B|C)
        say ""
        if [[ "${PHONE_OS}" == "iOS" ]]; then
            say "    Step-by-step for iOS:"
            say "    a) On the iPhone: WhatsApp → Settings → Chats → Chat Backup → Back Up Now"
            say "       (toggle 'Include Videos' OFF to save 70% time)"
            say "    b) Connect phone to this computer via USB."
            say "    c) Open Finder (macOS Catalina+) or iTunes (older). Make an ENCRYPTED backup."
            say "       REMEMBER THE BACKUP PASSWORD. We need it for decryption."
            say "    d) Use iMazing or a libimobiledevice script to extract:"
            say "       ChatStorage.sqlite + Message/Media folder"
            say "    e) Run a WhatsApp DB → .txt exporter (e.g. WhatsApp Viewer)."
            say "    f) Drop all generated .txt files into:"
            say "       ${EXPORTS_DIR}"
        else
            say "    Step-by-step for Android:"
            say "    a) On the phone: WhatsApp → Settings → Chats → Chat Backup → Back Up"
            say "       (local backup is fine; Google Drive needs separate key handling)"
            say "    b) Get the 64-char encryption key:"
            say "       Settings → Account → End-to-end encrypted backup → Manage → Reveal key"
            say "    c) Pull /sdcard/WhatsApp/Databases/msgstore.db.crypt15 to this computer (adb pull)"
            say "    d) Decrypt with the key (use https://github.com/ElDavoo/wa-crypt-tools)"
            say "    e) Convert decrypted SQLite → per-chat .txt (use whatsapp-viewer-pro or wa-export)"
            say "    f) Drop all generated .txt files into:"
            say "       ${EXPORTS_DIR}"
        fi
        say ""
        ask "Press Enter once .txt files are in ${EXPORTS_DIR}..." _CONFIRM
        ;;
esac

# ---- Step 5: pipeline --------------------------------------------------------

info "Step 5/6 — Run parser + extractor"

if [[ "${DELIVERY_PATH}" == "A" ]]; then
    ok "Skipped pipeline (Business API path; seed mode)"
else
    if [[ -z "$(ls -A "${EXPORTS_DIR}"/*.txt 2>/dev/null)" ]]; then
        err "No .txt files found in ${EXPORTS_DIR}. Aborting."
        exit 1
    fi

    ask "Owner display name as it appears in the exports (e.g. 'Sarah Fan')" OWNER_NAME

    say ""
    info "Parsing exports..."
    python3 "${SCRIPT_DIR}/whatsapp-export-parser.py" \
        --input "${EXPORTS_DIR}" \
        --output "${PROJECT_DIR}/parsed" \
        --owner-name "${OWNER_NAME}" \
        --salt "${EXPORT_SALT}" 2>&1 | tee -a "${LOG_FILE}"

    say ""
    info "Extracting customer profiles (this may take a few minutes)..."
    python3 "${SCRIPT_DIR}/customer-profile-extractor.py" \
        --parsed "${PROJECT_DIR}/parsed" \
        --output "${PROJECT_DIR}/profiles" \
        --min-turns 20 2>&1 | tee -a "${LOG_FILE}"

    say ""
    info "Mining Layer B golden segments (sales playbook)..."
    python3 "${SCRIPT_DIR}/mine-golden-segments.py" \
        --parsed "${PROJECT_DIR}/parsed" \
        --output "${PROJECT_DIR}/golden" \
        --min-score 3 2>&1 | tee -a "${LOG_FILE}"

    say ""
    info "Chunking Layer C conversation history..."
    python3 "${SCRIPT_DIR}/bulk-embed.py" \
        --parsed "${PROJECT_DIR}/parsed" \
        --output "${PROJECT_DIR}/layer-c-chunks.jsonl" 2>&1 | tee -a "${LOG_FILE}"
fi

# ---- Step 5b: optional push to PulseAgent -----------------------------------

if [[ "${DELIVERY_PATH}" != "A" ]]; then
    say ""
    ask_choice "Push to PulseAgent now?" PUSH_NOW \
        "No, I'll review and push later" \
        "Yes, push profiles to MemOS + chunks to KB"

    if [[ "${PUSH_NOW}" == Yes* ]]; then
        if [[ ! -f "${HOME}/.pa-config.json" && -z "${PA_ENDPOINT:-}" ]]; then
            warn "No ~/.pa-config.json or PA_ENDPOINT env var found."
            ask "PulseAgent endpoint URL (e.g. https://pa.example.com)" PA_ENDPOINT
            ask "PulseAgent API token (Bearer)" PA_TOKEN
            ask "Tenant slug" PA_TENANT
            export PA_ENDPOINT PA_TOKEN PA_TENANT
        fi
        say ""
        info "Upserting profiles to MemOS..."
        python3 "${SCRIPT_DIR}/memos-upsert.py" --profiles "${PROJECT_DIR}/profiles" 2>&1 | tee -a "${LOG_FILE}"
        say ""
        info "Uploading conversation chunks to KB..."
        python3 "${SCRIPT_DIR}/bulk-embed.py" --parsed "${PROJECT_DIR}/parsed" --upload 2>&1 | tee -a "${LOG_FILE}"
    fi
fi

# ---- Step 6: verification report --------------------------------------------

info "Step 6/6 — Verification report"

if [[ -d "${PROJECT_DIR}/profiles" ]]; then
    TOTAL=$(find "${PROJECT_DIR}/profiles" -name '*.yaml' | wc -l | tr -d ' ')
    AUTO_OK=$(grep -l '^_auto_onboard: true' "${PROJECT_DIR}/profiles"/*.yaml 2>/dev/null | wc -l | tr -d ' ')
    REVIEW=$(($(grep -l '^_auto_onboard: false' "${PROJECT_DIR}/profiles"/*.yaml 2>/dev/null | wc -l | tr -d ' ') + 0))
    say ""
    ok "Profiles total:         ${TOTAL}"
    ok "Auto-onboard approved:  ${AUTO_OK}"
    ok "Manual review queue:    ${REVIEW}"
    say ""
    if [[ -f "${PROJECT_DIR}/profiles/_manual_review.txt" ]]; then
        warn "Review queue file: ${PROJECT_DIR}/profiles/_manual_review.txt"
    fi
fi

say ""
say "============================================================"
ok "Bootstrap complete."
say ""
say "Next steps:"
say "  1. Open ${PROJECT_DIR}/profiles/_manual_review.txt and triage gated customers."
say "  2. Manually audit ${PROJECT_DIR}/golden/*.yaml — set _human_reviewed: true on keepers."
say "  3. If you skipped the push step, run:"
say "       python3 scripts/memos-upsert.py --profiles profiles"
say "       python3 scripts/bulk-embed.py   --parsed parsed --upload"
say "  4. Configure system prompt (docs/system-prompt-template.md)."
say "  5. Run the 5 pre-launch verification cases before going live."
say ""
say "Bootstrap log saved to: ${LOG_FILE}"
say "State file (resumable):  ${STATE_FILE}"
say "============================================================"
