locals {
  # Single source of truth for every LXC container in the cluster.
  # Add a service here and `terraform apply` provisions it end to end.
  containers = {
    pihole = {
      vm_id        = 100
      node_name    = "pve"
      description  = "Network-wide DNS filtering and DHCP"
      ip_address   = "192.168.1.20/24"
      cores        = 1
      memory       = 512
      disk_size    = 8
      datastore_id = "local-lvm"
      nesting      = false
    }
    n8n = {
      vm_id        = 101
      node_name    = "pve"
      description  = "Workflow automation (Shopify-to-Telegram reporting)"
      ip_address   = "192.168.1.23/24"
      cores        = 1
      memory       = 1024
      disk_size    = 8
      datastore_id = "local-lvm"
      nesting      = false
    }
    monitoring = {
      vm_id        = 103
      node_name    = "pve"
      description  = "Docker host: Prometheus, Grafana, Homepage dashboard"
      ip_address   = "192.168.1.30/24"
      cores        = 2
      memory       = 3072
      disk_size    = 20
      datastore_id = "local-lvm"
      nesting      = true # required to run Docker inside an unprivileged LXC
    }
    nextcloud = {
      vm_id        = 201
      node_name    = "pve2"
      description  = "Nextcloud (Docker + MariaDB) on the dedicated ZFS storage node"
      ip_address   = "192.168.1.41/24"
      cores        = 2
      memory       = 3072
      disk_size    = 8
      datastore_id = "local-zfs"
      nesting      = true
    }
  }
}

resource "proxmox_virtual_environment_container" "ct" {
  for_each = local.containers

  node_name   = each.value.node_name
  vm_id       = each.value.vm_id
  description = each.value.description
  tags        = ["terraform", each.key]

  unprivileged  = true
  start_on_boot = true
  started       = true

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = each.value.datastore_id
    size         = each.value.disk_size
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = each.value.ip_address
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      password = var.ct_password
      keys     = var.ssh_public_keys
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
  }

  operating_system {
    template_file_id = var.ct_template
    type             = "debian"
  }

  features {
    nesting = each.value.nesting
  }

  lifecycle {
    # The template id can drift as Debian point releases are published; that
    # alone should not trigger a destroy/recreate of a running container.
    ignore_changes = [operating_system]
  }
}
