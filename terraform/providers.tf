terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

# Proxmox VE API connection.
# Credentials are supplied via variables (see variables.tf / terraform.tfvars.example);
# never hard-code the API token here.
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure # self-signed PVE certificate in the homelab

  # SSH is used by the provider for operations the API cannot perform on its own
  # (e.g. uploading templates, some container actions).
  ssh {
    agent    = true
    username = var.proxmox_ssh_username
  }
}
