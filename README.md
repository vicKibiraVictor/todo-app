# 📋 Taskflow — Todo App with PostgreSQL + Kubernetes

A full-stack todo app: React frontend · Node.js/Express backend · PostgreSQL database · Kubernetes deployment.

---

## 📁 Project Structure

```
todo-app/
├── backend/          # Node.js + Express REST API
│   ├── index.js
│   ├── package.json
│   └── Dockerfile
├── frontend/         # React app
│   ├── src/App.js
│   ├── public/index.html
│   ├── nginx.conf
│   └── Dockerfile
├── k8s/              # Kubernetes manifests
│   ├── 00-namespace.yaml
│   ├── 01-postgres.yaml
│   ├── 02-backend.yaml
│   └── 03-frontend.yaml
├── docker-compose.yml
└── README.md
```

---

## ✅ Prerequisites

- Docker + Docker Hub account
- kubectl + a running cluster (Minikube, kind, or cloud)
- Node.js 18+ (for local dev only)

---

## 🧪 STEP 1 — Run Locally with Docker Compose (test first!)

```bash
cd todo-app

# Build and start all services (postgres + backend + frontend)
docker-compose up --build

# App is now running at:
# Frontend → http://localhost:3000
# Backend  → http://localhost:5000
# Postgres → localhost:5432
```

To stop:
```bash
docker-compose down
# To also delete DB volume:
docker-compose down -v
```

---

## 🐳 STEP 2 — Build & Push Images to Docker Hub

Replace `YOUR_USERNAME` with your actual Docker Hub username.

```bash
# Login to Docker Hub
docker login

# Build backend image
docker build -t YOUR_USERNAME/todo-backend:latest ./backend

# Build frontend image
docker build -t YOUR_USERNAME/todo-frontend:latest ./frontend

# Push both images
docker push YOUR_USERNAME/todo-backend:latest
docker push YOUR_USERNAME/todo-frontend:latest
```

---

## ☸️ STEP 3 — Update Kubernetes Manifests

Edit `k8s/02-backend.yaml` and `k8s/03-frontend.yaml` — replace:
```
image: YOUR_DOCKERHUB_USERNAME/todo-backend:latest
image: YOUR_DOCKERHUB_USERNAME/todo-frontend:latest
```
with your actual Docker Hub username.

---

## ☸️ STEP 4 — Deploy to Kubernetes

```bash
# If using Minikube, start it first:
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

## 🌐 STEP 5 — Access the App in Browser

### If using Minikube:
```bash
minikube service frontend -n todo-app
# This opens the browser automatically!

# Or get the URL manually:
minikube service frontend -n todo-app --url
```

### If using a cloud cluster (NodePort):
```bash
# Get the node external IP
kubectl get nodes -o wide

# Access at:  http://<NODE_EXTERNAL_IP>:30080
```

### If you want to use port-forwarding instead:
```bash
kubectl port-forward svc/frontend 8080:80 -n todo-app
# Then open: http://localhost:8080
```

---

## 🔍 Useful Debug Commands

```bash
# Check all resources in the namespace
kubectl get all -n todo-app

# Check pod logs
kubectl logs -l app=backend -n todo-app
kubectl logs -l app=postgres -n todo-app
kubectl logs -l app=frontend -n todo-app

# Describe a pod (useful for crash debugging)
kubectl describe pod -l app=backend -n todo-app

# Connect to postgres inside the cluster
kubectl exec -it deployment/postgres -n todo-app -- psql -U postgres -d tododb

# Scale backend replicas
kubectl scale deployment backend --replicas=3 -n todo-app
```

---

## 🔄 API Endpoints

| Method | Endpoint         | Description        |
|--------|------------------|--------------------|
| GET    | /api/todos       | Get all todos      |
| GET    | /api/todos/:id   | Get single todo    |
| POST   | /api/todos       | Create todo        |
| PUT    | /api/todos/:id   | Update todo        |
| DELETE | /api/todos/:id   | Delete todo        |
| GET    | /health          | Health check       |

### Example POST body:
```json
{
  "title": "Buy groceries",
  "description": "Milk, eggs, bread",
  "priority": "high"
}
```

---

## 🧹 Teardown

```bash
# Delete everything
kubectl delete namespace todo-app
```
