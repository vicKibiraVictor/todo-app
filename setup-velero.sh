#!/bin/bash
# =============================================================================
# setup-velero.sh — Install Velero on Minikube using MinIO as backup storage
# =============================================================================

set -euo pipefail

NAMESPACE="velero"
MINIO_NAMESPACE="minio"
BUCKET="todo-backups"
VELERO_VERSION="v1.13.0"

echo ""
echo "================================================"
echo " Velero + MinIO Backup Setup for Minikube"
echo "================================================"
echo ""

# ── Step 1: Install Velero CLI ───────────────────────────────────────────────
echo "[1/6] Installing Velero CLI..."

if command -v velero >/dev/null 2>&1; then
  echo "    Velero already installed"
else
  wget -q https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz

  tar -xzf velero-${VELERO_VERSION}-linux-amd64.tar.gz

  sudo mv velero-${VELERO_VERSION}-linux-amd64/velero /usr/local/bin/

  rm -rf velero-${VELERO_VERSION}-linux-amd64*
fi

echo "    ✅ Velero CLI installed: $(velero version --client-only 2>/dev/null | head -1)"

# ── Step 2: Deploy MinIO inside the cluster ──────────────────────────────────
echo ""
echo "[2/6] Deploying MinIO (in-cluster object storage)..."

kubectl create namespace ${MINIO_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

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
          args:
            - server
            - /data
            - --console-address
            - ":9001"
          env:
            - name: MINIO_ROOT_USER
              value: "minio"
            - name: MINIO_ROOT_PASSWORD
              value: "minio123"
          ports:
            - containerPort: 9000
            - containerPort: 9001
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
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          emptyDir: {}
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

kubectl rollout status deployment/minio \
  -n ${MINIO_NAMESPACE} \
  --timeout=120s

echo "    ✅ MinIO is ready"

# ── Step 4: Create MinIO bucket ──────────────────────────────────────────────
echo ""
echo "[4/6] Creating bucket '${BUCKET}' in MinIO..."

kubectl run minio-setup \
  --rm -i --restart=Never \
  --image=minio/mc:latest \
  --namespace=${MINIO_NAMESPACE} \
  --command -- /bin/sh -c "
    mc alias set local http://minio:9000 minio minio123 &&
    mc mb --ignore-existing local/${BUCKET} &&
    echo 'Bucket created successfully'
  "

echo "    ✅ Bucket '${BUCKET}' ready"

# ── Step 5: Create Velero credentials ────────────────────────────────────────
echo ""
echo "[5/6] Writing Velero credentials..."

cat > /tmp/velero-credentials <<EOF
[default]
aws_access_key_id=minio
aws_secret_access_key=minio123
EOF

echo "    ✅ Credentials file created"

# ── Step 6: Install Velero ───────────────────────────────────────────────────
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

rm -f /tmp/velero-credentials

echo ""
echo "    Waiting for Velero deployment to be ready..."

kubectl rollout status deployment/velero \
  -n ${NAMESPACE} \
  --timeout=180s

echo ""
echo "================================================"
echo " ✅ Velero + MinIO setup complete!"
echo "================================================"
echo ""

echo "Useful commands:"
echo ""
echo "  Check Velero pods:"
echo "    kubectl get pods -n velero"
echo ""
echo "  Check MinIO pods:"
echo "    kubectl get pods -n minio"
echo ""
echo "  Create backup:"
echo "    velero backup create todo-backup"
echo ""
echo "  View backups:"
echo "    velero backup get"
echo ""
echo "  Describe backup:"
echo "    velero backup describe todo-backup"
echo ""
echo "  Restore backup:"
echo "    velero restore create --from-backup todo-backup"
echo ""
echo "  Access MinIO console:"
echo "    kubectl port-forward svc/minio -n minio 9001:9001"
echo ""
echo "    Open: http://localhost:9001"
echo "    Username: minio"
echo "    Password: minio123"
echo ""