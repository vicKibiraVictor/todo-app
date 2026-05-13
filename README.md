# Taskflow

A full-stack todo application built with React, Node.js/Express, and PostgreSQL — deployable locally with Docker Compose or to any Kubernetes cluster.

![Stack](https://img.shields.io/badge/stack-React%20%7C%20Node.js%20%7C%20PostgreSQL-blue)
![Deploy](https://img.shields.io/badge/deploy-Kubernetes-326ce5?logo=kubernetes&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [Docker Hub](#docker-hub)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Accessing the App](#accessing-the-app)
- [API Reference](#api-reference)
- [Debugging](#debugging)
- [Backups](#backups)
- [Monitoring](#monitoring)
- [Teardown](#teardown)

---

## Overview

Taskflow is a CRUD todo app with:

- **Frontend** — React SPA served via Nginx
- **Backend** — Node.js + Express REST API
- **Database** — PostgreSQL with persistent volume storage
- **Infra** — Docker Compose for local dev; Kubernetes manifests for production

---

## Project Structure

```
todo-app/
├── backend/
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── frontend/
│   ├── src/App.js
│   ├── public/index.html
│   ├── nginx.conf
│   └── Dockerfile
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-postgres.yaml
│   ├── 02-backend.yaml
│   ├── 03-frontend.yaml
│   ├── 04-backup-schedule.yaml             ← Velero schedules
│   ├── 05-postgres-backup-cronjob.yaml     ← pg_dump CronJob
│   └── monitoring/
│       ├── 00-namespaces.yaml              ← monitoring + logging namespaces
│       ├── prometheus-values.yaml          ← Prometheus + Grafana config
│       ├── opensearch-values.yaml          ← OpenSearch config
│       ├── opensearch-dashboards-values.yaml
│       ├── fluentbit-values.yaml           ← log shipper config
│       ├── grafana-dashboards.yaml         ← custom dashboards ConfigMap
│       └── 06-app-metrics.yaml            ← backend + Postgres metrics (future)
├── setup-velero.sh                         ← run once for backups
├── backup-now.sh                           ← manual backup anytime
├── restore.sh                              ← restore from any backup
├── check-backups.sh                        ← see all backup status
├── setup-monitoring.sh                     ← run once for monitoring
├── open-dashboards.sh                      ← port-forward all UIs
├── check-monitoring.sh                     ← monitoring stack health check
├── docker-compose.yml
└── README.md
```

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| Docker + Docker Hub account | Building and pushing images |
| `kubectl` + a running cluster | Kubernetes deployment (Minikube, kind, or cloud) |
| Node.js 18+ | Local development only |

---

## Local Development

The fastest way to get started — runs Postgres, the backend, and the frontend together.

```bash
cd todo-app

# Build and start all services
docker-compose up --build
```

| Service  | URL |
|----------|-----|
| Frontend | http://localhost:3000 |
| Backend  | http://localhost:5000 |
| Postgres | localhost:5432 |

```bash
# Stop services
docker-compose down

# Stop and delete the DB volume
docker-compose down -v
```

---

## Docker Hub

Build and push images before deploying to Kubernetes. Replace `YOUR_USERNAME` with your Docker Hub username.

```bash
# Authenticate
docker login

# Build images
docker build -t YOUR_USERNAME/todo-backend:latest ./backend
docker build -t YOUR_USERNAME/todo-frontend:latest ./frontend

# Push images
docker push YOUR_USERNAME/todo-backend:latest
docker push YOUR_USERNAME/todo-frontend:latest
```

---

## Kubernetes Deployment

### 1. Update image references

In `k8s/02-backend.yaml` and `k8s/03-frontend.yaml`, replace the placeholder with your Docker Hub username:

```yaml
image: YOUR_DOCKERHUB_USERNAME/todo-backend:latest
image: YOUR_DOCKERHUB_USERNAME/todo-frontend:latest
```

### 2. Apply manifests

```bash
# Start Minikube if running locally
minikube start

# Apply all manifests in order
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-postgres.yaml
kubectl apply -f k8s/02-backend.yaml
kubectl apply -f k8s/03-frontend.yaml

# Watch pods come up (wait for all Running)
kubectl get pods -n todo-app -w
```

---

## Accessing the App

### Minikube

```bash
# Open the app in your browser automatically
minikube service frontend -n todo-app

# Or get the URL manually
minikube service frontend -n todo-app --url
```

### Cloud cluster (NodePort)

```bash
# Get the external IP of any node
kubectl get nodes -o wide

# Access at:
http://<NODE_EXTERNAL_IP>:30080
```

### Port-forwarding (any cluster)

```bash
kubectl port-forward svc/frontend 8080:80 -n todo-app
# Open: http://localhost:8080
```

---

## API Reference

Base path: `/api`

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/todos` | Get all todos |
| `GET` | `/todos/:id` | Get a single todo |
| `POST` | `/todos` | Create a todo |
| `PUT` | `/todos/:id` | Update a todo |
| `DELETE` | `/todos/:id` | Delete a todo |
| `GET` | `/health` | Health check |

**Example — create a todo:**

```bash
curl -X POST http://localhost:5000/api/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Buy groceries",
    "description": "Milk, eggs, bread",
    "priority": "high"
  }'
```

---

## Debugging

```bash
# All resources in the namespace
kubectl get all -n todo-app

# Stream pod logs
kubectl logs -l app=backend -n todo-app
kubectl logs -l app=postgres -n todo-app
kubectl logs -l app=frontend -n todo-app

# Describe a pod (useful for crash-loop debugging)
kubectl describe pod -l app=backend -n todo-app

# Open a Postgres shell inside the cluster
kubectl exec -it deployment/postgres -n todo-app -- psql -U postgres -d tododb

# Scale backend replicas
kubectl scale deployment backend --replicas=3 -n todo-app
```

---

## Backups

Two-layer backup strategy: Velero for full cluster state + a pg_dump CronJob for Postgres data.

| Layer | Tool | What it backs up | Schedule |
|-------|------|-----------------|----------|
| Cluster state | Velero + MinIO | All K8s resources (Deployments, Services, Secrets, PVCs) | Hourly (24h retention) · Daily (7d retention) |
| Database data | pg_dump CronJob | Actual rows inside Postgres | Every 6 hours, last 28 dumps kept |

> **Why both?** Velero backs up PVC *metadata*, not the data inside the database. pg_dump captures the actual rows.
> MinIO runs inside the cluster — no cloud account needed.

### One-time setup

```bash
# Make scripts executable
chmod +x setup-velero.sh backup-now.sh restore.sh check-backups.sh

# Install Velero CLI, deploy MinIO inside the cluster, and create the bucket
./setup-velero.sh

# Apply the Velero schedules and pg_dump CronJob
kubectl apply -f k8s/04-backup-schedule.yaml
kubectl apply -f k8s/05-postgres-backup-cronjob.yaml

# Run a manual backup to confirm everything works
./backup-now.sh

# Verify
./check-backups.sh
```

### Day-to-day commands

```bash
# See all backups at a glance
./check-backups.sh

# Trigger a manual backup right now
./backup-now.sh

# List everything available to restore from
./restore.sh list

# Restore the full namespace from a Velero backup
./restore.sh velero todo-app-daily-20241115020000

# Restore just the database from a pg_dump
./restore.sh postgres postgres_20241115_060000.sql.gz
```

---

## Monitoring

Full observability stack: **Prometheus + Grafana** for metrics and **OpenSearch + Fluent Bit** for logs. Tuned for Minikube on GitHub Codespaces (4 CPU / 7GB RAM).

| Tool | Role | Namespace |
|------|------|-----------|
| Prometheus | Scrapes metrics from all pods, nodes, and K8s objects | `monitoring` |
| Grafana | Dashboards wired to Prometheus; custom cluster dashboard pre-loaded | `monitoring` |
| Alertmanager | Fires alerts on threshold breaches (bundled with Prometheus) | `monitoring` |
| OpenSearch | Stores and indexes all pod logs | `logging` |
| OpenSearch Dashboards | Log search and visualization UI | `logging` |
| Fluent Bit | DaemonSet that ships logs from every pod → OpenSearch | `logging` |

> **What's monitored now:** cluster health — nodes, pods, CPU, memory, restarts.
> **Coming later:** backend API metrics and Postgres — files are pre-written, just uncomment `k8s/monitoring/06-app-metrics.yaml`.

### One-time setup

```bash
# Make scripts executable
chmod +x setup-monitoring.sh open-dashboards.sh check-monitoring.sh

# Install Helm, deploy all charts, and apply dashboards (~5–8 min)
./setup-monitoring.sh
```

### Access the dashboards

```bash
# Port-forward all three UIs in the background
./open-dashboards.sh
```

| Port | UI | Credentials |
|------|----|-------------|
| 3000 | Grafana | `admin` / `taskflow-grafana` |
| 9090 | Prometheus | — |
| 5601 | OpenSearch Dashboards | — |

> **Codespaces:** open the **Ports tab** at the bottom of VS Code and click the 🌐 globe icon next to each port to open in your browser.

### Check stack health

```bash
# Shows pod status, PVCs, services, and resource usage for both namespaces
./check-monitoring.sh

# Live pod watch
kubectl get pods -n monitoring -w
kubectl get pods -n logging -w

# Grafana logs
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring

# Prometheus logs
kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring

# Fluent Bit logs (confirm it's shipping)
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30

# OpenSearch logs
kubectl logs -n logging -l app=opensearch-cluster-master --tail=30
```

### Grafana — recommended dashboards to import

In Grafana go to **Dashboards → Import → paste the ID → Load**.

| ID | Dashboard |
|----|-----------|
| 15661 | Kubernetes Cluster (all namespaces) |
| 13332 | Kubernetes Pods |
| 1860 | Node Exporter Full (host CPU, memory, disk, network) |
| 17375 | Kubernetes Namespace Overview |

A custom **Taskflow Cluster Overview** dashboard is pre-loaded automatically on install. It shows pod CPU/memory, running vs not-running pod counts, node utilisation gauges, and a container restart table.

### OpenSearch — finding your logs

1. Open OpenSearch Dashboards at `http://localhost:5601`
2. Go to **Stack Management → Index Patterns → Create**
3. Set the pattern to `kube-*` and the time field to `@timestamp`
4. Go to **Discover** and filter by namespace:

```
kubernetes.namespace_name: "todo-app"
kubernetes.namespace_name: "monitoring"
kubernetes.namespace_name: "logging"
```

Fluent Bit ships logs under daily indices (`kube-YYYY.MM.DD`) and automatically enriches each log line with pod name, namespace, container name, and labels.

### Enable app metrics + Postgres monitoring (later)

When you're ready to monitor the backend API and database:

**Step 1** — add `prom-client` to the backend:
```bash
cd backend && npm install prom-client
```
Then expose a `GET /metrics` endpoint in `index.js` (Prometheus will scrape it automatically).

**Step 2** — uncomment and apply the pre-written manifest:
```bash
# Uncomment the ServiceMonitor and postgres-exporter blocks in the file, then:
kubectl apply -f k8s/monitoring/06-app-metrics.yaml
```

This adds a ServiceMonitor that tells Prometheus to scrape `/metrics` from the backend, and deploys `postgres-exporter` which exposes connection count, query latency, table bloat, and more.

### Teardown monitoring only

```bash
helm uninstall kube-prometheus -n monitoring
helm uninstall opensearch -n logging
helm uninstall opensearch-dashboards -n logging
helm uninstall fluent-bit -n logging
kubectl delete namespace monitoring logging
```

---

## Teardown

```bash
# Remove the app
kubectl delete namespace todo-app

# Remove everything (app + monitoring + logging)
kubectl delete namespace todo-app monitoring logging
```

---

## License

MIT