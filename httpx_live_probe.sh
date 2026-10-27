#!/usr/bin/env bash
# =============================================================================
# Workflow: httpx live-host probing for CONA / Coca-Cola Intigtrity scope
# Compatible: Local bash + GitHub Actions (ubuntu-latest)
# Repo: /home/sali/BugBounty_Lab/COCO/222/
# =============================================================================
set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="${SCRIPT_DIR}/all_s.txt"
OUTPUT_FILE="${SCRIPT_DIR}/live_brute_hosts.jsonl"
LOG_FILE="${SCRIPT_DIR}/httpx_run.log"

# Intigtrity researcher identity (per program rules of engagement)
export INTIGRITI_USERNAME="${INTIGRITI_USERNAME:-sabry313}"
export PROGRAM_UA="${PROGRAM_UA:-YOUR_REQUIRED_STANDARD_USER_AGENT intigriti:${INTIGRITI_USERNAME}}"

# httpx flags (exact per user specification)
HTTPX_FLAGS=(
  -l "${INPUT_FILE}"
  -silent
  -json
  -status-code
  -title
  -tech-detect
  -web-server
  -content-length
  -content-type
  -location
  -ip
  -cname
  -cdn
  -asn
  -response-time
  -method
  -hash mmh3
  -rate-limit 7
  -threads 1
  -timeout 10
  -H "User-Agent: ${PROGRAM_UA}"
  -H "X-Intigtrity-Username: ${INTIGRITI_USERNAME}"
  -o "${OUTPUT_FILE}"
)

# Telegram notification (optional — set BOT_TOKEN and CHAT_ID as GitHub Secrets or env vars)
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

send_telegram() {
  local message="$1"
  if [[ -z "${TELEGRAM_BOT_TOKEN}" || -z "${TELEGRAM_CHAT_ID}" ]]; then
    echo "[telegram] skipped: BOT_TOKEN or CHAT_ID not set"
    return 0
  fi
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${message}" \
    -d "parse_mode=Markdown" >/dev/null 2>&1 || true
}

# --- Pre-flight checks ---
echo "[workflow] Starting httpx live-host probe"
echo "[workflow] Input file: ${INPUT_FILE}"
echo "[workflow] Output file: ${OUTPUT_FILE}"
echo "[workflow] Domains to probe: $(wc -l < "${INPUT_FILE}")"
echo "[workflow] INTIGRITI_USERNAME=${INTIGRITI_USERNAME}"
echo "[workflow] PROGRAM_UA=${PROGRAM_UA}"
echo "[workflow] Rate limit: 7 req/s (within 10 req/s program cap)"
echo "[workflow] Threads: 1"

if [[ ! -f "${INPUT_FILE}" ]]; then
  echo "[workflow] ERROR: Input file not found: ${INPUT_FILE}" >&2
  send_telegram "❌ *httpx workflow failed* — input file not found: \`${INPUT_FILE}\`"
  exit 1
fi

command -v httpx >/dev/null 2>&1 || {
  echo "[workflow] ERROR: httpx not found in PATH" >&2
  send_telegram "❌ *httpx workflow failed* — httpx binary not found"
  exit 1
}

# --- Clear previous output ---
: > "${OUTPUT_FILE}"

# --- Execute httpx ---
echo "[workflow] Running httpx..."
START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

httpx "${HTTPX_FLAGS[@]}" 2>&1 | tee "${LOG_FILE}"

END_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# --- Post-run summary ---
LIVE_COUNT=$(wc -l < "${OUTPUT_FILE}" 2>/dev/null || echo 0)
echo "=============================================="
echo "[workflow] httpx probe completed"
echo "[workflow] Start:  ${START_TS}"
echo "[workflow] End:    ${END_TS}"
echo "[workflow] Live hosts: ${LIVE_COUNT}"
echo "[workflow] Output:   ${OUTPUT_FILE}"
echo "=============================================="

# Notify via Telegram
send_telegram "✅ *httpx workflow completed* — CONA/COCO scope
*Input:* \`all_s.txt\` (\$(wc -l < "${INPUT_FILE}") domains)
*Live hosts:* \`${LIVE_COUNT}\`
*Output:* \`live_brute_hosts.jsonl\`
*Period:* \`${START_TS}\` → \`${END_TS}\`
*Rate limit:* 7 req/s | *Headers:* X-Intigtrity-Username: ${INTIGRITI_USERNAME}"

exit 0