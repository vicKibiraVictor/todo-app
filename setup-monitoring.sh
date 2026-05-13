#!/bin/bash
set -e

# ─────────────────────────────────────────────
#  Taskflow — Monitoring Stack Setup
#  Prometheus · Grafana · OpenSearch · Fluent Bit
#  Designed for Minikube on GitHub Codespaces
# ─────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── 1. Minikube resource check ────────────────
info "Configuring Minikube for Codespaces (4 CPU / 7GB RAM)..."
minikube config set cpus 4
minikube config set memory 7168

if ! minikube status | grep -q "Running"; then
  info "Starting Minikube..."
  minikube start --driver=docker --cpus=4 --memory=7168
else
  success "Minikube already running"
fi

# Enable metrics-server addon (required for kubectl top)
minikube addons enable metrics-server
success "metrics-server enabled"

# ── 2. Install Helm if missing ────────────────
if ! command -v helm &>/dev/null; then
  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
success "Helm $(helm version --short) ready"

# ── 3. Add Helm repos ─────────────────────────
info "Adding Helm repos..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana             https://grafana.github.io/helm-charts
helm repo add opensearch          https://opensearch-project.github.io/helm-charts
helm repo add fluent              https://fluent.github.io/helm-charts
helm repo update
success "Helm repos updated"

# ── 4. Namespaces ─────────────────────────────
kubectl apply -f k8s/monitoring/00-namespaces.yaml
success "Namespaces created"

# ── 5. Prometheus + Grafana (kube-prometheus-stack) ──
info "Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
helm upgrade --install kube-prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values k8s/monitoring/prometheus-values.yaml \
  --wait --timeout 5m
success "Prometheus + Grafana installed"

# ── 6. OpenSearch ─────────────────────────────
info "Installing OpenSearch..."
helm upgrade --install opensearch \
  opensearch/opensearch \
  --namespace logging \
  --values k8s/monitoring/opensearch-values.yaml \
  --wait --timeout 5m
success "OpenSearch installed"

# ── 7. OpenSearch Dashboards ──────────────────
info "Installing OpenSearch Dashboards..."
helm upgrade --install opensearch-dashboards \
  opensearch/opensearch-dashboards \
  --namespace logging \
  --values k8s/monitoring/opensearch-dashboards-values.yaml \
  --wait --timeout 3m
success "OpenSearch Dashboards installed"

# ── 8. Fluent Bit (log shipper) ───────────────
info "Installing Fluent Bit..."
helm upgrade --install fluent-bit \
  fluent/fluent-bit \
  --namespace logging \
  --values k8s/monitoring/fluentbit-values.yaml \
  --wait --timeout 3m
success "Fluent Bit installed"

# ── 9. Apply dashboards ConfigMap ────────────
kubectl apply -f k8s/monitoring/grafana-dashboards.yaml
success "Grafana dashboards imported"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Monitoring stack installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Run ./open-dashboards.sh to access all UIs"
echo ""
