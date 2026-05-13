#!/bin/bash
# =============================================================================
# setup-velero.sh — Install Velero on Minikube using MinIO as the backup store
# MinIO runs inside the cluster itself (no cloud account needed)
# =============================================================================

set -e

NAMESPACE="velero"
MINIO_NAMESPACE="minio"
BUCKET="todo-backups"

echo ""
echo "================================================"
echo " Velero + MinIO Backup Setup for Minikube"
echo "================================================"
echo ""

# ── Step 1: Install Velero CLI ───────────────────────────────────────────────
echo "[1/6] Installing Velero CLI..."

VELERO_VERSION="v1.13.0"
wget -q https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz
tar -xzf velero-${VELERO_VERSION}-linux-amd64.tar.gz
sudo mv velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/
rm -rf velero-${VELERO_VERSION}-linux-amd64*
echo "    ✅ Velero CLI installed: $(velero version --client-only 2>/dev/null | head -1)"

# ── Step 2: Deploy MinIO inside the cluster ──────────────────────────────────
echo ""
echo "[2/6] Deploying MinIO (in-cluster object storage)..."

kubectl create namespace ${MINIO_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: ${MINIO_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - name: minio
          image: minio/minio:latest
          args: ["server", "/data", "--console-address", ":9001"]
          env:
            - name: MINIO_ROOT_USER
              value: "minio"
            - name: MINIO_ROOT_PASSWORD
              value: "minio123"
          ports:
            - containerPort: 9000   # API
            - containerPort: 9001   # Console UI
          volumeMounts:
            - name: data
              mountPath: /data
          readinessProbe:
            httpGet:
              path: /minio/health/ready
              port: 9000
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /minio/health/live
              port: 9000
            initialDelaySeconds: 20
            periodSeconds: 20
      volumes:
        - name: data
          emptyDir: {}   # fine for dev; swap for PVC in production
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: ${MINIO_NAMESPACE}
spec:
  selector:
    app: minio
  ports:
    - name: api
      port: 9000
      targetPort: 9000
    - name: console
      port: 9001
      targetPort: 9001
EOF

echo "    ✅ MinIO deployed"

# ── Step 3: Wait for MinIO to be ready ───────────────────────────────────────
echo ""
echo "[3/6] Waiting for MinIO pod to be ready..."
kubectl rollout status deployment/minio -n ${MINIO_NAMESPACE} --timeout=120s
echo "    ✅ MinIO is ready"

# ── Step 4: Create the backup bucket inside MinIO ────────────────────────────
echo ""
echo "[4/6] Creating bucket '${BUCKET}' in MinIO..."

kubectl run minio-setup --rm -i --restart=Never \
  --image=minio/mc:latest \
  --namespace=${MINIO_NAMESPACE} \
  -- sh -c "
    mc alias set local http://minio:9000 minio minio123 --api S3v4 &&
    mc mb --ignore-existing local/${BUCKET} &&
    echo 'Bucket created'
  "
echo "    ✅ Bucket '${BUCKET}' ready"

# ── Step 5: Write Velero credentials file ────────────────────────────────────
echo ""
echo "[5/6] Writing Velero credentials..."

cat > /tmp/velero-credentials <<EOF
[default]
aws_access_key_id=minio
aws_secret_access_key=minio123
EOF

# ── Step 6: Install Velero into the cluster ───────────────────────────────────
echo ""
echo "[6/6] Installing Velero into the cluster..."

velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.9.0 \
  --bucket ${BUCKET} \
  --secret-file /tmp/velero-credentials \
  --use-volume-snapshots=false \
  --backup-location-config \
    region=minio,s3ForcePathStyle=true,s3Url=http://minio.${MINIO_NAMESPACE}.svc.cluster.local:9000

rm /tmp/velero-credentials

echo ""
echo "    Waiting for Velero deployment to be ready..."
kubectl rollout status deployment/velero -n ${NAMESPACE} --timeout=120s

echo ""
echo "================================================"
echo " ✅ Velero + MinIO setup complete!"
echo "================================================"
echo ""
echo " Next steps:"
echo "   Run a manual backup now:  ./backup-now.sh"
echo "   Check backup status:      velero backup get"
echo "   Schedule daily backups:   kubectl apply -f k8s/backup/04-backup-schedule.yaml"
echo ""