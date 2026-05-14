#!/bin/bash

# ─────────────────────────────────────────────────────
#  open-dashboards.sh
#  Port-forwards all monitoring UIs in the background
#  Works in GitHub Codespaces (use the Ports tab to open)
# ─────────────────────────────────────────────────────

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Kill any existing port-forwards for these ports
for port in 3000 9090 5601; do
  pid=$(lsof -ti tcp:$port 2>/dev/null)
  [ -n "$pid" ] && kill "$pid" 2>/dev/null && echo "Killed existing process on port $port"
done

sleep 1

# ── Grafana — port 3000 ───────────────────────────────
info "Starting Grafana port-forward → localhost:3000"
kubectl port-forward svc/kube-prometheus-grafana 3000:80 \
  -n monitoring &>/tmp/pf-grafana.log &
GRAFANA_PID=$!

# ── Prometheus — port 9090 ───────────────────────────
info "Starting Prometheus port-forward → localhost:9090"
kubectl port-forward svc/kube-prometheus-kube-prome-prometheus 9090:9090 \
  -n monitoring &>/tmp/pf-prometheus.log &
PROM_PID=$!

# ── OpenSearch Dashboards — port 5601 ────────────────
info "Starting OpenSearch Dashboards port-forward → localhost:5601"
kubectl port-forward svc/opensearch-dashboards 5601:5601 \
  -n logging &>/tmp/pf-opensearch.log &
OS_PID=$!

sleep 3

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Monitoring dashboards are live!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  📊 Grafana              → ${CYAN}http://localhost:3000${NC}"
echo -e "     Username: admin      Password: taskflow-grafana"
echo ""
echo -e "  🔥 Prometheus           → ${CYAN}http://localhost:9090${NC}"
echo ""
echo -e "  🔍 OpenSearch Dashboards → ${CYAN}http://localhost:5601${NC}"
echo ""
echo -e "${YELLOW}  In GitHub Codespaces:${NC}"
echo "  Open the Ports tab (bottom panel) → click the globe icon next to each port"
echo ""
echo "  PIDs: Grafana=$GRAFANA_PID  Prometheus=$PROM_PID  OpenSearch=$OS_PID"
echo "  To stop all: kill $GRAFANA_PID $PROM_PID $OS_PID"
echo ""

# ── Recommended Grafana dashboards to import ──────────
echo -e "${YELLOW}  Suggested dashboards to import in Grafana (Dashboards → Import → paste ID):${NC}"
echo "   • 15661  — Kubernetes Cluster (all namespaces)"
echo "   • 13332  — Kubernetes Pods"
echo "   • 1860   — Node Exporter Full"
echo "   • 17375  — Kubernetes Namespace Overview"
echo ""

# Keep script running so port-forwards stay alive
wait
