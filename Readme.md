# Thmanyah SRE Challenge

A microservices infrastructure challenge exploring Kubernetes deployment, service isolation, observability, and failure recovery across **Node.js, Go, and Python** services.

## Start here

- [Architecture diagram](architecture.png)
- [Failure scenarios](scenarios.md)
- Service code: [Node.js API](server.js), [Go authentication service](main.go), and [Python image service](main.py)
- Kubernetes manifests: [API](thmanyah-api.yaml), [authentication](musahha-auth.yaml), [image service](khazna-images.yaml), and [PostgreSQL](postgresql.yaml)
- Observability: [Prometheus](prometheus.yaml), [Grafana](grafana.yaml), [Alertmanager](alertmanager.yaml), and [dashboard definition](thmanyah-api-dashboard.json)
- Isolation and routing: [namespaces](namespace.yaml), [network policies](network-policies.yaml), and [ingress](ingress.yaml)

## Engineering focus

The architecture separates an API entry point, authentication, and image processing. PostgreSQL provides structured storage, while the image-service design uses S3-compatible object storage. Kubernetes manifests describe deployment and service configuration; Prometheus, Grafana, and Alertmanager support the monitoring design.

The failure exercises cover a database outage, an authentication-service crash, and a traffic spike. They are intended to help examine service degradation, alerts, resource behavior, and recovery.

These are **lab scenarios**, not measured production outcomes. This README does not claim a verified recovery time, uptime, or load capacity.

## Repository layout and reproduction status

The public snapshot stores source files, manifests, and scripts at the repository root. The existing [setup script](setup.sh) still refers to a different directory layout, including services/, k8s/, and failure-simulations/. Those directories are absent from this snapshot, so the script is **not a working one-command quick start** as published.

For review, begin with the linked source, manifests, diagram, and scenario description. Reproducing the full lab requires reconciling build contexts, file paths, image names, and environment configuration. A fresh end-to-end deployment was not performed as part of this documentation update.

## Failure exercise artifacts

- [Database outage script](database-outage.sh)
- [Authentication crash script](auth-service-crash.sh)
- [Traffic spike script](traffic-spike.sh)

Review and adapt these scripts before use in an isolated lab. They change workload state and retain assumptions about the original project layout.

## Learning connection to AI Engineering

This project demonstrates the infrastructure side of an engineering portfolio: service boundaries, container deployment, telemetry, and failure investigation. Those foundations also matter when serving and monitoring AI applications. The project itself is an SRE challenge and does not implement model training, RAG, or model-quality evaluation.

For more recent reliability projects, see [KubeMedic](https://github.com/NajwaN96/kubemedic) and [OpsPilot](https://github.com/NajwaN96/opspilot).
