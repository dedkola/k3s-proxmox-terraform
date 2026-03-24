terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure = var.proxmox_insecure

  ssh {
    agent = true


    node {
      name = "${var.proxmox_node}"
      address = "192.168.0.250"
    }
  }
}

# ──────────────────────────────────────────────
# Cloud-init snippets (uploaded to Proxmox)
# ──────────────────────────────────────────────

resource "proxmox_virtual_environment_file" "cloud_init_user" {
  for_each     = local.vms
  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init-user.yaml.tftpl", {
      hostname   = each.value.name
      ssh_keys   = var.ssh_public_keys
      username   = var.vm_user
      packages   = ["curl", "wget", "git", "jq", "htop", "nfs-utils", "iptables"]
      role       = each.value.role
      k3s_server = each.value.role == "agent" ? local.server_ip : ""
    })
    file_name = "cloud-init-${each.value.name}.yaml"
  }
}

# ──────────────────────────────────────────────
# Fedora VMs
# ──────────────────────────────────────────────

resource "proxmox_virtual_environment_vm" "k3s" {
  for_each  = local.vms
  name      = each.value.name
  node_name = var.proxmox_node
  vm_id     = each.value.vmid

  tags = ["k3s", each.value.role, "terraform"]

  # ── Hardware ──
  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  # ── Boot disk (clone from Fedora template) ──
  clone {
    vm_id = var.fedora_template_vmid
    full  = true
  }

  disk {
    interface    = "scsi0"
    datastore_id = var.vm_datastore
    size         = each.value.disk_size
    discard      = "on"
    ssd          = true
  }

  # ── Network ──
  network_device {
    bridge  = var.network_bridge
    model   = "virtio"
  }

  # ── Cloud-init ──
  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user[each.key].id
  }

  lifecycle {
    ignore_changes = [
      disk[0].size,
    ]
  }
}
