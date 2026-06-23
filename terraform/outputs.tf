output "containers" {
  description = "Provisioned containers with their node, VM id and IP address."
  value = {
    for name, ct in proxmox_virtual_environment_container.ct :
    name => {
      node  = ct.node_name
      vm_id = ct.vm_id
      ip    = local.containers[name].ip_address
    }
  }
}
