#!/bin/bash
# =============================================================================
# check-backups.sh — Show status of all backups at a glance
# =============================================================================

echo ""
echo "============================================"
echo " Backup Status Report — $(date)"
echo "============================================"

# ── Velero backups ────────────────────────────────────────────────────────────
echo ""
echo "── Velero Backups ──────────────────────────"
velero backup get 2>/dev/null || echo "  Velero not installed or not reachable"

# ── Velero schedules ──────────────────────────────────────────────────────────
echo ""
echo "── Velero Schedules ────────────────────────"
velero schedule get 2>/dev/null || echo "  No schedules found"

# ── pg_dump files in MinIO ────────────────────────────────────────────────────
echo ""
echo "── Postgres Dumps in MinIO ─────────────────"
kubectl run mc-check --rm -i --restart=Never \
  --image=minio/mc:latest \
  --namespace=minio \
  -- sh -c "
    mc alias set backup http://minio:9000 minio minio123 --api S3v4 --quiet 2>/dev/null
    echo 'Files in todo-backups/postgres/:'
    mc ls backup/todo-backups/postgres/ 2>/dev/null || echo '  No dumps found'
    echo ''
    echo 'Total size:'
    mc du backup/todo-backups/postgres/ 2>/dev/null || echo '  Unable to calculate'
  " 2>/dev/null || echo "  MinIO pod not reachable"

# ── Recent backup CronJob runs ────────────────────────────────────────────────
echo ""
echo "── Recent pg_dump CronJob History ──────────"
kubectl get jobs -n todo-app | grep postgres-backup || echo "  No backup jobs found"

# ── Last backup job logs ──────────────────────────────────────────────────────
LAST_POD=$(kubectl get pods -n todo-app \
  --sort-by=.metadata.creationTimestamp \
  | grep postgres-backup \
  | tail -1 \
  | awk '{print $1}' 2>/dev/null || echo "")

if [ -n "$LAST_POD" ]; then
  echo ""
  echo "── Last Backup Job Logs (${LAST_POD}) ──────"
  kubectl logs "$LAST_POD" -n todo-app --tail=10 2>/dev/null || echo "  Logs not available"
fi

echo ""
echo "============================================"
echo " Commands:"
echo "   Manual backup now:      ./backup-now.sh"
echo "   Restore velero:         ./restore.sh velero <name>"
echo "   Restore postgres:       ./restore.sh postgres <file.sql.gz>"
echo "   List all backups:       ./restore.sh list"
echo "============================================"
echo ""