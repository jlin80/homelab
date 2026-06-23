# Homelab — Self-Hosted Infrastructure as Code

A 2-node bare-metal **Proxmox VE 9** cluster running self-hosted services in
unprivileged LXC containers, provisioned declaratively with **Terraform**.

This repository is the source of truth for the container fleet: adding a service
is a few lines in [`terraform/containers.tf`](terraform/containers.tf) followed
by a single `terraform apply`.

> Network addresses in this repo use the example subnet `192.168.1.0/24`.
> Set your own values in `terraform.tfvars` / `variables.tf`.

## Architecture

```
[ pve  — node 1: services ]            [ pve2 — node 2: storage ]
  HP t610 · Debian 13                     HP t610 · Debian 13 · ZFS (1 TB, lz4)
  192.168.1.10                            192.168.1.11
  ├── CT100  Pi-hole   DNS/DHCP           ├── rpool/backups  → NFS export
  ├── CT101  n8n         automation       │     ▲ daily cluster-wide vzdump
  └── CT103  monitoring  Docker host      │       (7-day retention)
                                          └── CT201  Nextcloud (Docker + MariaDB)
                                                    multi-user + per-user quotas
         └──────────────── vzdump backups ─────────────────┘
```

Both nodes are joined in a single Proxmox cluster (`homelab-cluster`), so the
NFS backup datastore on node 2 is available cluster-wide.

## Services

| CT  | Service   | Node | IP           | Purpose                                              |
|-----|-----------|------|--------------|------------------------------------------------------|
| 100 | Pi-hole   | pve  | 192.168.1.20 | Network-wide DNS filtering and DHCP                  |
| 101 | n8n       | pve  | 192.168.1.23 | Workflow automation (Shopify → Telegram reporting)   |
| 103 | monitoring | pve  | 192.168.1.30 | Docker host: Prometheus, Grafana, Homepage dashboard |
| 201 | Nextcloud | pve2 | 192.168.1.41 | File sync & photo backup (Docker + MariaDB)          |

## Stack

- **Virtualization:** Proxmox VE 9 (2-node cluster), unprivileged LXC
- **IaC:** Terraform with the [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest) provider
- **Storage:** ZFS (lz4 compression) + NFS, automated `vzdump` backups with retention
- **Networking:** Pi-hole DNS/DHCP, Tailscale for secure remote access
- **Containers:** Docker / Docker Compose (Nextcloud, and the monitoring stack)
- **Observability:** Prometheus + Grafana + Homepage dashboard

## Usage

```bash
cd terraform

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

## Secrets

No secrets are committed. The Proxmox API token, container password and SSH keys
are read from `terraform.tfvars` (git-ignored) or `TF_VAR_*` environment
variables. State files (`*.tfstate`) are git-ignored as well, since they can
contain sensitive values.

## Notes

The containers in this repo were originally created by hand and later codified
in Terraform as the cluster grew. To adopt the running containers into Terraform
state without recreating them, use `terraform import` per resource, e.g.:

```bash
terraform import 'proxmox_virtual_environment_container.ct["pihole"]' pve/100
```
