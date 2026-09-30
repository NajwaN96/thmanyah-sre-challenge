## Architecture Design

This system is made up of three core microservices, each written in a different programming language to highlight both language diversity and varying operational needs:

- \`\`\*\* (Node.js):\*\* The main API gateway — it’s the entry point for all client requests.
- \`\`\*\* (Go):\*\* Handles user authentication and authorization.
- \`\`\*\* (Python):\*\* Takes care of storing and processing image files.

These services connect to a PostgreSQL database (for storing structured data) and an S3-compatible object storage system (for image assets). Everything runs on Kubernetes, which helps us keep the system scalable, resilient, and resource-efficient.

### Component Isolation and Security

To keep things secure and properly segmented, here’s what we’ve implemented:

- **Namespaces:** Each service lives in its own Kubernetes namespace (e.g., `thmanyah-api-ns`). This setup makes it easier to manage access controls and isolate resources.
- **Network Policies:** We lock down pod-to-pod communication using strict network rules — services only talk to the ones they need to.
- **Secrets Management:** Sensitive configs (like DB credentials or API keys) are managed via Kubernetes Secrets. These are mounted safely into pods. In production, we'd use something more robust like HashiCorp Vault or Sealed Secrets.
- **TLS Ingress:** External traffic is encrypted via TLS. For now, we’re using self-signed certs, but the setup is ready for production-grade certificates from something like Let’s Encrypt.

## Setup and Deployment

To make deployment smooth, we created automation scripts that handle everything from building the services to verifying that they’re running properly.

### Prerequisites

Here’s what you need before you start:

**System:**

- Kubernetes cluster (v1.20+)
- `kubectl` configured and authenticated
- Docker running for building images
- Minimum 4GB RAM, 2 CPU cores
- Internet access to pull images and dependencies

**Access:**

- Cluster admin privileges
- Permissions to create secrets and apply policies
- Ingress controller installed (we used nginx-ingress)

This setup works with local clusters like Minikube or cloud providers like EKS, GKE, and AKS. The script checks all the above before doing anything.

### Automated Deployment

Run this script to get started:

```bash
cd thmanyah-sre-assessment
./scripts/setup.sh
```

This script walks through the following steps:

**1. Environment Validation:** Checks your tools, access, and cluster health.

**2. Image Building:** Builds Docker images for each service. We follow best practices — non-root users, lean base images, and pinned dependencies.

**3. Namespace Creation:** Sets up dedicated namespaces: one per service and one for monitoring.

**4. Secrets:** Applies secrets for things like database credentials and JWT keys.

**5. Database Deployment:** Deploys PostgreSQL with persistent storage and some sample data.

**6. Microservices Deployment:** Deploys all services with proper configs (resource limits, health checks, auto-scaling).

**7. Network Policies:** Applies firewall-like rules between pods.

**8. Ingress Setup:** Adds TLS-enabled routing to expose services.

**9. Monitoring Stack:** Brings up Prometheus, Grafana, and Alertmanager — all pre-configured.

**10. Verification:** Checks pod health, connectivity, and general system readiness.

### Manual Deployment

If you’d rather deploy everything step-by-step (or want to understand how it all works), here’s the manual flow:

**Build Images:**

```bash
cd services/thmanyah-api
docker build -t thmanyah-api:latest .

cd ../musahha-auth
docker build -t musahha-auth:latest .

cd ../khazna-images
docker build -t khazna-images:latest .
```

**Create Namespaces:**

```bash
kubectl create namespace thmanyah-api-ns
kubectl create namespace musahha-auth-ns
kubectl create namespace khazna-images-ns
kubectl create namespace monitoring
```

**Deploy Secrets:**

```bash
kubectl apply -f k8s/secrets/database-secret.yaml
```

**Deploy Database:**

```bash
kubectl apply -f k8s/deployments/postgresql.yaml
kubectl wait --for=condition=ready pod -l app=postgresql -n thmanyah-api-ns --timeout=300s
```

**Deploy Services:**

```bash
kubectl apply -f k8s/deployments/thmanyah-api.yaml
kubectl apply -f k8s/deployments/musahha-auth.yaml
kubectl apply -f k8s/deployments/khazna-images.yaml
```

**Configure Networking:**

```bash
kubectl apply -f k8s/network-policies.yaml
kubectl apply -f k8s/ingress/
```

**Deploy Monitoring:**

```bash
kubectl apply -f k8s/monitoring/
```

### Accessing Services (Locally)

Use port-forwarding to test the services:

**Main API:**

```bash
kubectl port-forward -n thmanyah-api-ns svc/thmanyah-api 3000:3000
```

**Auth Service:**

```bash
kubectl port-forward -n musahha-auth-ns svc/musahha-auth 8080:8080
```

**Images Service:**

```bash
kubectl port-forward -n khazna-images-ns svc/khazna-images 5000:5000
```

### Observability

**Prometheus:**

```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```

Use it to dig into metrics and query performance over time.

**Grafana:**

```bash
kubectl port-forward -n monitoring svc/grafana 3001:3000
```

Default creds: `admin/admin123`. Comes with dashboards showing response times, errors, resource usage, and business metrics.

**Alertmanager:**

```bash
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

This manages alerts and can push them to Slack/email/etc.

---

## Failure Scenarios & Recovery

To prove the system can take a hit and bounce back, we simulate a few common failure situations. Each test checks if the system can recover gracefully without manual fixes.

### 1. Database Outage

```bash
./failure-simulations/database-outage.sh
```

We simulate a DB crash by scaling PostgreSQL to 0. The API should stop working on DB-dependent routes but still pass health checks. Alerts get fired, and once the DB is restored, everything should pick up automatically.

### 2. Auth Service Crash

```bash
./failure-simulations/auth-service-crash.sh
```

Kills all auth pods. Kubernetes should restart them instantly. During this time, login endpoints will fail gracefully. Recovery is fast — under a minute.

### 3. Traffic Spike

```bash
./failure-simulations/traffic-spike.sh
```

We slam the images service with heavy traffic to trigger horizontal scaling. The system should detect the load, spin up more pods, and then scale down once things calm down. Metrics will show spike and recovery clearly.

---

## What This Proves

Each failure scenario shows that:

- Kubernetes catches and reacts to failures quickly
- Services degrade gracefully (no domino effect)
- The system recovers without human help
- Alerts notify the team early
- Metrics and dashboards give visibility into what’s happening

