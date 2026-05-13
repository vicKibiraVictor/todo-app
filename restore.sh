#!/bin/bash
# =============================================================================
# restore.sh — Restore from backup (Velero namespace OR Postgres pg_dump)
# Usage:
#   ./restore.sh velero <backup-name>
#   ./restore.sh postgres <filename>   e.g. postgres_20241115_060000.sql.gz
#   ./restore.sh list                  list all available backups
# =============================================================================

set -e

MODE=$1
TARGET=$2

list_backups() {
  echo ""
  echo "=== Velero Backups ==="
  velero backup get
  echo ""
  echo "=== Postgres Dumps in MinIO ==="
  kubectl run mc-list --rm -i --restart=Never \
    --image=minio/mc:latest \
    --namespace=minio \
    -- sh -c "
      mc alias set backup http://minio:9000 minio minio123 --api S3v4 --quiet &&
      mc ls backup/todo-backups/postgres/
    " 2>/dev/null || echo "  (MinIO not reachable — is the minio pod running?)"
  echo ""
}

restore_velero() {
  BACKUP_NAME=$1
  if [ -z "$BACKUP_NAME" ]; then
    echo "ERROR: provide a backup name"
    echo "Usage: ./restore.sh velero <backup-name>"
    echo ""
    velero backup get
    exit 1
  fi

  echo ""
  echo "============================================"
  echo " Velero Restore: ${BACKUP_NAME}"
  echo "============================================"
  echo ""
  echo "⚠️  This will restore ALL resources in the todo-app namespace."
  echo "   Existing resources will be left as-is (use --existing-resource-policy=update to overwrite)."
  echo ""
  read -p "Continue? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi

  RESTORE_NAME="restore-${BACKUP_NAME}-$(date +%H%M%S)"

  velero restore create "${RESTORE_NAME}" \
    --from-backup "${BACKUP_NAME}" \
    --include-namespaces todo-app \
    --wait

  echo ""
  velero restore describe "${RESTORE_NAME}" --details
  echo ""
  echo "✅ Velero restore complete"
  echo ""
  echo "Check pods:  kubectl get pods -n todo-app"
}

restore_postgres() {
  FILENAME=$1
  if [ -z "$FILENAME" ]; then
    echo "ERROR: provide a dump filename"
    echo "Usage: ./restore.sh postgres postgres_20241115_060000.sql.gz"
    echo ""
    echo "Available dumps:"
    kubectl run mc-list --rm -i --restart=Never \
      --image=minio/mc:latest \
      --namespace=minio \
      -- sh -c "mc alias set b http://minio:9000 minio minio123 --api S3v4 --quiet && mc ls b/todo-backups/postgres/" 2>/dev/null
    exit 1
  fi

  echo ""
  echo "============================================"
  echo " Postgres Restore: ${FILENAME}"
  echo "============================================"
  echo ""
  echo "⚠️  This will DROP and recreate the todos table and restore all data."
  echo ""
  read -p "Continue? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi

  echo "Running restore job..."

  kubectl run postgres-restore \
    --rm -i --restart=Never \
    --image=postgres:15-alpine \
    --namespace=todo-app \
    --env="PGHOST=postgres" \
    --env="PGPORT=5432" \
    --env="PGUSER=postgres" \
    --env="PGDATABASE=tododb" \
    --overrides='{
      "spec": {
        "containers": [{
          "name": "postgres-restore",
          "image": "postgres:15-alpine",
          "env": [
            {"name":"PGHOST","value":"postgres"},
            {"name":"PGPORT","value":"5432"},
            {"name":"PGDATABASE","value":"tododb"},
            {"name":"PGUSER","valueFrom":{"secretKeyRef":{"name":"postgres-secret","key":"POSTGRES_USER"}}},
            {"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"postgres-secret","key":"POSTGRES_PASSWORD"}}}
          ],
          "command": ["/bin/sh","-c","
            apk add --no-cache wget --quiet &&
            wget -q https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc &&
            chmod +x /usr/local/bin/mc &&
            mc alias set backup http://minio.minio.svc.cluster.local:9000 minio minio123 --api S3v4 --quiet &&
            mc cp backup/todo-backups/postgres/'"${FILENAME}"' /tmp/restore.sql.gz &&
            gunzip /tmp/restore.sql.gz &&
            echo Dropping existing todos table... &&
            psql -c DROP TABLE IF EXISTS todos CASCADE &&
            echo Restoring data... &&
            psql < /tmp/restore.sql &&
            echo Restore complete &&
            psql -c SELECT COUNT(*) FROM todos
          "]
        }],
        "restartPolicy": "Never"
      }
    }' -- sleep 1

  echo ""
  echo "✅ Postgres restore complete"
}

# ── Main ─────────────────────────────────────────────────────────────────────
case "$MODE" in
  list)
    list_backups
    ;;
  velero)
    restore_velero "$TARGET"
    ;;
  postgres)
    restore_postgres "$TARGET"
    ;;
  *)
    echo ""
    echo "Usage:"
    echo "  ./restore.sh list                              — list all backups"
    echo "  ./restore.sh velero <backup-name>              — restore full namespace"
    echo "  ./restore.sh postgres <filename.sql.gz>        — restore postgres data"
    echo ""
    list_backups
    ;;
esac