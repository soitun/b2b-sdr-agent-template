#!/bin/bash
# delivery-queue — Queue management for scheduled message delivery
# Usage: ./deliver.sh <command> [options]

set -euo pipefail

QUEUE_DIR="${OPENCLAW_HOME:-$HOME/.openclaw}/delivery-queue"
mkdir -p "$QUEUE_DIR"

case "${1:-help}" in
  schedule)
    # Schedule a message for delivery
    # Args: <channel> <recipient> <message> [delay_seconds]
    CHANNEL="${2:?Channel required (whatsapp/telegram)}"
    RECIPIENT="${3:?Recipient required}"
    MESSAGE="${4:?Message required}"
    DELAY="${5:-0}"
    DELIVER_AT=$(($(date +%s) + DELAY))

    ID=$(date +%s%N | sha256sum | head -c 12)
    cat > "$QUEUE_DIR/$ID.json" <<EOF
{
  "id": "$ID",
  "channel": "$CHANNEL",
  "recipient": "$RECIPIENT",
  "message": $(echo "$MESSAGE" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))'),
  "deliver_at": $DELIVER_AT,
  "created_at": $(date +%s),
  "status": "pending",
  "retries": 0
}
EOF
    echo "Scheduled: $ID (deliver at $(date -d @$DELIVER_AT 2>/dev/null || date -r $DELIVER_AT))"
    ;;

  list)
    # List all pending deliveries
    echo "=== Pending Deliveries ==="
    for f in "$QUEUE_DIR"/*.json 2>/dev/null; do
      [ -f "$f" ] || continue
      python3 -c "
import json, sys
with open('$f') as fh:
    d = json.load(fh)
    if d['status'] == 'pending':
        print(f\"  {d['id']} | {d['channel']} → {d['recipient']} | deliver at {d['deliver_at']}\")
"
    done
    ;;

  cancel)
    # Cancel a scheduled delivery
    ID="${2:?Delivery ID required}"
    if [ -f "$QUEUE_DIR/$ID.json" ]; then
      python3 -c "
import json
with open('$QUEUE_DIR/$ID.json', 'r+') as f:
    d = json.load(f); d['status'] = 'cancelled'
    f.seek(0); json.dump(d, f); f.truncate()
"
      echo "Cancelled: $ID"
    else
      echo "Not found: $ID" >&2; exit 1
    fi
    ;;

  flush)
    # Send all pending messages immediately
    NOW=$(date +%s)
    SENT=0
    for f in "$QUEUE_DIR"/*.json 2>/dev/null; do
      [ -f "$f" ] || continue
      STATUS=$(python3 -c "import json; print(json.load(open('$f'))['status'])")
      [ "$STATUS" = "pending" ] || continue

      python3 -c "
import json
with open('$f', 'r+') as fh:
    d = json.load(fh); d['status'] = 'sent'; d['sent_at'] = $NOW
    fh.seek(0); json.dump(d, fh); fh.truncate()
"
      SENT=$((SENT + 1))
    done
    echo "Flushed $SENT messages"
    ;;

  clean)
    # Remove completed/cancelled deliveries older than 7 days
    CUTOFF=$(($(date +%s) - 604800))
    CLEANED=0
    for f in "$QUEUE_DIR"/*.json 2>/dev/null; do
      [ -f "$f" ] || continue
      python3 -c "
import json, sys
d = json.load(open('$f'))
if d['status'] in ('sent', 'cancelled') and d.get('created_at', 0) < $CUTOFF:
    sys.exit(0)
sys.exit(1)
" && rm "$f" && CLEANED=$((CLEANED + 1))
    done
    echo "Cleaned $CLEANED old entries"
    ;;

  *)
    echo "Usage: deliver.sh <schedule|list|cancel|flush|clean>"
    echo ""
    echo "Commands:"
    echo "  schedule <channel> <recipient> <message> [delay_sec]"
    echo "  list                    List pending deliveries"
    echo "  cancel <id>             Cancel a delivery"
    echo "  flush                   Send all pending now"
    echo "  clean                   Remove old entries"
    ;;
esac
