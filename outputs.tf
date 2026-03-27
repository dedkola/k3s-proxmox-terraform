output "server_ip" {
  description = "K3s server node IP"
  value       = local.server_ip
}

output "vm_ips" {
  description = "All VM IPs by role"
  value = {
    for key, vm in local.vms : vm.name => vm.ip
  }
}

output "ssh_commands" {
  description = "Quick SSH commands"
  value = {
    for key, vm in local.vms : vm.name => "ssh ${var.vm_user}@${var.network_prefix}.${var.ip_offset + index(keys(local.vms), key)}"
  }
}

output "kubeconfig_command" {
  description = "Command to fetch kubeconfig from server"
  value       = "ssh ${var.vm_user}@${local.server_ip} 'sudo cat /etc/rancher/k3s/k3s.yaml' | sed 's/127.0.0.1/${local.server_ip}/g' > ~/.kube/k3s-config"
}

output "metallb_ip_range" {
  description = "MetalLB L2 address pool range"
  value       = var.metallb_enabled ? var.metallb_ip_range : "MetalLB disabled"
}
