#!/bin/bash

# ─────────────────────────────────────────────────────
#  check-monitoring.sh
#  Shows the status of every monitoring component
# ─────────────────────────────────────────────────────

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

section() { echo -e "\n${CYAN}━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

section "Pods — monitoring namespace"
kubectl get pods -n monitoring -o wide

section "Pods — logging namespace"
kubectl get pods -n logging -o wide

section "Persistent Volumes"
kubectl get pvc -n monitoring
kubectl get pvc -n logging

section "Services"
kubectl get svc -n monitoring
kubectl get svc -n logging

section "Prometheus targets (scraped endpoints)"
echo -e "${YELLOW}Tip: run ./open-dashboards.sh then visit http://localhost:9090/targets${NC}"

section "Recent Fluent Bit logs (last 20 lines)"
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=20 2>/dev/null || \
  echo "Fluent Bit not yet running"

section "Resource usage"
kubectl top pods -n monitoring 2>/dev/null || echo "metrics-server not ready yet"
kubectl top pods -n logging    2>/dev/null

echo ""
echo -e "${GREEN}Done. Run ./open-dashboards.sh to access the UIs.${NC}"
