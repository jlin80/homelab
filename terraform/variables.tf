variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint (cluster node 1)."
  type        = string
  default     = "https://192.168.1.10:8006/"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!tokenid=uuid'. Set via terraform.tfvars or TF_VAR_proxmox_api_token; never commit it."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (the homelab uses a self-signed PVE certificate)."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user the provider uses for node operations."
  type        = string
  default     = "root"
}

variable "ct_template" {
  description = "LXC template file id used for all containers."
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.1-1_amd64.tar.zst"
}

variable "ct_password" {
  description = "Initial root password for the containers. Set via terraform.tfvars or TF_VAR_ct_password; never commit it."
  type        = string
  sensitive   = true
}

variable "ssh_public_keys" {
  description = "SSH public keys injected into every container for key-based root access."
  type        = list(string)
  default     = []
}

variable "network_gateway" {
  description = "Default IPv4 gateway for all containers."
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers for all containers (Pi-hole first)."
  type        = list(string)
  default     = ["192.168.1.20"]
}

variable "network_bridge" {
  description = "Proxmox bridge all containers attach to."
  type        = string
  default     = "vmbr0"
}
