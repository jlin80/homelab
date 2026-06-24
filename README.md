# Homelab — Infrastructure as Code

![Terraform](https://img.shields.io/badge/Terraform-1.6+-7B42BC?logo=terraform)
![Proxmox](https://img.shields.io/badge/Proxmox-VE_9-E57000?logo=proxmox)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)
![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s-326CE5?logo=kubernetes)
![Loki](https://img.shields.io/badge/Loki-Logs-F8C726?logo=grafana)
![CI](https://github.com/jlin80/homelab/actions/workflows/terraform.yml/badge.svg)
![Deploy](https://github.com/jlin80/homelab/actions/workflows/deploy.yml/badge.svg)

A 2-node bare-metal **Proxmox VE 9** cluster running self-hosted services in
LXC containers, provisioned declaratively with **Terraform** — extended with
Kubernetes (k3s), GitHub Actions CI/CD, full-stack observability (metrics + logs + alerts),
and cloud infrastructure on AWS.

This repository is the source of truth for the container fleet: adding a service
is a few lines in [`terraform/containers.tf`](terraform/containers.tf) followed
by a single `terraform apply`.

> Network addresses in this repo use the example subnet `192.168.1.0/24`.
> Set your own values in `terraform.tfvars` / `variables.tf`.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         GitHub                               │
│              push to main → triggers CI/CD pipeline          │
└──────────────────────┬──────────────────────────────────────┘
                       │ GitHub Actions (self-hosted runner)
                       ▼
             docker compose up + kubectl apply

[ pve  — node 1: services ]            [ pve2 — node 2: storage ]
  HP t610 · Debian 13                     HP t610 · Debian 13 · ZFS (1 TB, lz4)
  192.168.1.10                            192.168.1.11
  ├── CT100  Pi-hole    DNS/DHCP          ├── rpool/backups  → NFS export
  ├── CT101  n8n        automation        │     ▲ daily cluster-wide vzdump
  ├── CT102  k3s        Kubernetes        │       (7-day retention)
  └── CT103  monitoring Docker+CI/CD      └── CT201  Nextcloud (Docker + MariaDB)

         └──────────────── vzdump backups ─────────────────┘
```

Both nodes are joined in a single Proxmox cluster (`homelab-cluster`), so the
NFS backup datastore on node 2 is available cluster-wide.

## Screenshots

### Homepage dashboard
Live status of both Proxmox nodes, Pi-hole, n8n, Nextcloud, Grafana and Prometheus.

![Homepage dashboard](docs/homepage.png)

### Grafana — Blackbox Exporter
HTTP uptime and probe latency for Pi-hole, n8n and both Proxmox nodes.

![Grafana Blackbox Exporter](docs/grafana-blackbox.png)

### Grafana — Kubernetes (kube-state-metrics)
Pod state and resource usage scraped from k3s via Prometheus.

![Grafana Kubernetes dashboard](docs/grafana-k8s.png)

### Grafana — Loki (logs centralizados)
Docker container logs centralized in Loki, queried from Grafana.

![Grafana Loki logs](docs/grafana-loki.png)

### Grafana — Prometheus Explore
`kube_pod_info` showing all pods in the homelab-k3s cluster across namespaces.

![Grafana Prometheus Explore](docs/grafana-explore.png)

### Proxmox cluster
Two-node cluster (`pve` + `pve2`) with LXC containers and cluster storage.

![Proxmox Datacenter](docs/proxmox-cluster.png)

## Services

| CT  | Service    | Node | IP           | Purpose                                             |
|-----|------------|------|--------------|-----------------------------------------------------|
| 100 | Pi-hole    | pve  | 192.168.1.20 | Network-wide DNS filtering and DHCP                 |
| 101 | n8n        | pve  | 192.168.1.23 | Workflow automation (Shopify → Telegram reporting)  |
| 102 | k3s        | pve  | 192.168.1.40 | Kubernetes cluster (k3s) + Helm                     |
| 103 | monitoring | pve  | 192.168.1.30 | Docker host: observability stack + CI/CD runner     |
| 201 | Nextcloud  | pve2 | 192.168.1.41 | File sync & photo backup (Docker + MariaDB)         |

## Stack

- **Virtualization:** Proxmox VE 9 (2-node cluster), unprivileged LXC
- **IaC (homelab):** Terraform with the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest) provider
- **IaC (cloud):** Terraform with the AWS provider (VPC, EC2, Security Groups)
- **Orchestration:** k3s (Kubernetes) + Helm v3
- **CI/CD:** GitHub Actions + self-hosted runner (Docker container in CT103)
- **Storage:** ZFS (lz4 compression) + NFS, automated `vzdump` backups with retention
- **Networking:** Pi-hole DNS/DHCP, Tailscale for secure remote access
- **Containers:** Docker / Docker Compose
- **Metrics:** Prometheus + Grafana + kube-state-metrics + Blackbox Exporter + Node Exporter
- **Logs:** Loki + Promtail
- **Alerts:** Alertmanager → Telegram (ProbeDown, CPU > 80%, RAM > 85%, Pod Failed)

## Projects

### CI/CD Pipeline — GitHub Actions
**[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)**

Every push to `main` automatically:
1. Pulls updated Docker images
2. Redeploys the monitoring stack in CT103
3. Applies Kubernetes manifests to k3s in CT102
4. Verifies all pods are running

The runner is a Docker container in CT103 with access to the Docker socket
and the k3s kubeconfig (stored as a GitHub Actions secret).

### Kubernetes — k3s
**[`k8s/`](k8s/)**

Lightweight Kubernetes running in a Proxmox LXC container.

```bash
kubectl apply -f k8s/mi-app.yml -n portfolio
kubectl get all -n portfolio

# Self-healing demo — k8s recreates the pod automatically
kubectl delete pod <pod-name> -n portfolio
kubectl get pods -n portfolio --watch
```

Concepts: Deployments, ReplicaSets, Services, Namespaces, Helm charts,
resource limits/requests, self-healing, metrics-server.

### AWS Cloud Infrastructure
**[`cloud-engineer-portfolio/vpc-ec2/`](cloud-engineer-portfolio/vpc-ec2/)**

Full AWS networking stack deployed with Terraform on Free Tier:
VPC, public + private subnets, Internet Gateway, Security Groups, EC2 t2.micro.

```bash
cd cloud-engineer-portfolio/vpc-ec2/
terraform init && terraform apply
terraform destroy   # when done, avoids charges
```

### Observability Stack
**[`monitoring/`](monitoring/)**

CT103 runs a complete observability stack — metrics, logs, and alerts:

| Component | Role |
|---|---|
| Prometheus | Scrapes and stores metrics |
| Grafana | Dashboards and visualization |
| Node Exporter | Host metrics (CPU, RAM, disk) |
| Blackbox Exporter | HTTP/TCP uptime probing |
| Pi-hole Exporter | DNS metrics |
| kube-state-metrics | Kubernetes cluster state |
| metrics-server | Pod CPU/RAM (`kubectl top`) |
| Loki | Log aggregation |
| Promtail | Log collector (Docker + system logs) |
| Alertmanager | Routes alerts to Telegram |

**Alert rules:** ProbeDown (service down > 2min), CPUAlta (> 80% for 5min),
RAMAlta (> 85% for 5min), PodCaidoK8s (Failed pod in portfolio namespace).

```bash
cd monitoring/
cp .env.example .env        # fill in Grafana, Pi-hole, Telegram credentials
docker compose up -d
```

**Grafana dashboards:** `1860` (Node Exporter), `7587` (Blackbox), `13332` (Kube State Metrics), `15760` (Kubernetes Global)

## Usage

```bash
cd terraform/

# 1. Provide your secrets (git-ignored)
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars        # API token, container password, SSH keys

# 2. Initialize and review
terraform init
terraform plan

# 3. Apply
terraform apply
```

### Prerequisites

- Terraform >= 1.6
- A Proxmox API token (`Datacenter → Permissions → API Tokens`)
- The Debian 13 LXC template downloaded on each node
  (`pveam update && pveam download local debian-13-standard_...`)
- AWS CLI configured (for `cloud-engineer-portfolio/`)

## Secrets

No secrets are committed. Sensitive values are handled via:

- `terraform.tfvars` (git-ignored) or `TF_VAR_*` env vars — Proxmox API token, passwords, SSH keys
- GitHub Actions secrets — `KUBECONFIG_K3S` for k3s access from the runner
- `monitoring/.env` (git-ignored) — Grafana, Pi-hole, and Telegram credentials
- `*.tfstate` files are git-ignored (may contain sensitive values)

## Notes

The containers in this repo were originally created by hand and later codified
in Terraform as the cluster grew. To adopt the running containers into Terraform
state without recreating them, use `terraform import` per resource, e.g.:

```bash
terraform import 'proxmox_virtual_environment_container.ct["pihole"]' pve/100
```
