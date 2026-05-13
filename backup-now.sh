#!/bin/bash
# =============================================================================
# backup-now.sh — Trigger a manual backup immediately (both Velero + pg_dump)
# =============================================================================

set -e

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo ""
echo "============================================"
echo " Manual Backup — ${TIMESTAMP}"
echo "============================================"
echo ""

# ── 1. Velero: full namespace snapshot ───────────────────────────────────────
echo "[1/2] Running Velero namespace backup..."

velero backup create "todo-app-manual-${TIMESTAMP}" \
  --include-namespaces todo-app \
  --wait

echo ""
velero backup describe "todo-app-manual-${TIMESTAMP}" --details
echo "    ✅ Velero backup complete"

# ── 2. pg_dump: trigger the CronJob manually as a one-off Job ────────────────
echo ""
echo "[2/2] Running Postgres pg_dump backup..."

kubectl create job \
  "postgres-backup-manual-${TIMESTAMP}" \
  --from=cronjob/postgres-backup \
  -n todo-app

echo "    Job created — watching logs..."
echo ""

# Wait for the job pod to appear then stream its logs
sleep 5
POD=$(kubectl get pods -n todo-app \
  -l job-name="postgres-backup-manual-${TIMESTAMP}" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD" ]; then
  kubectl logs -f "$POD" -n todo-app
else
  echo "    Waiting for pod... check with:"
  echo "    kubectl get pods -n todo-app | grep postgres-backup-manual"
fi

echo ""
echo "============================================"
echo " ✅ Manual backup finished"
echo "============================================"
echo ""
echo " Check Velero backups:   velero backup get"
echo " Check pg_dump files:    ./check-backups.sh"
echo ""