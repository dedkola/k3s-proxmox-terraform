locals {
  server_ip = "${var.network_prefix}.${var.ip_offset}"

  vms = {
    server = {
      name      = "k3s-server"
      role      = "server"
      vmid      = var.vmid_offset
      cores     = var.server_cores
      memory    = var.server_memory
      disk_size = var.server_disk
      ip        = "${var.network_prefix}.${var.ip_offset}${var.cidr}"
    }
    agent1 = {
      name      = "k3s-agent-1"
      role      = "agent"
      vmid      = var.vmid_offset + 1
      cores     = var.agent_cores
      memory    = var.agent_memory
      disk_size = var.agent_disk
      ip        = "${var.network_prefix}.${var.ip_offset + 1}${var.cidr}"
    }
    agent2 = {
      name      = "k3s-agent-2"
      role      = "agent"
      vmid      = var.vmid_offset + 2
      cores     = var.agent_cores
      memory    = var.agent_memory
      disk_size = var.agent_disk
      ip        = "${var.network_prefix}.${var.ip_offset + 2}${var.cidr}"
    }
  }
}
