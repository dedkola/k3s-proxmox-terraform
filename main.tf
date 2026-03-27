terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure = var.proxmox_insecure

  ssh {
    agent = true
    username = "root"
    private_key = file("~/.ssh/id_ed25519")

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
      packages   = ["curl", "wget", "git", "jq", "htop", "nfs-common", "iptables", "qemu-guest-agent"]
      role       = each.value.role
      k3s_server = each.value.role == "agent" ? local.server_ip : ""
      k3s_token  = var.k3s_token
    })
    file_name = "cloud-init-${each.value.name}.yaml"
  }
}

# ──────────────────────────────────────────────
# Ubuntu VMs
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

  # ── Boot disk (clone from Ubuntu template) ──
  clone {
    vm_id = var.ubuntu_template_vmid
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
      domain  = var.dns_domain
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

# ──────────────────────────────────────────────
# Fetch kubeconfig once K3s server is ready
# ──────────────────────────────────────────────

resource "null_resource" "kubeconfig" {
  depends_on = [proxmox_virtual_environment_vm.k3s]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for K3s API on ${local.server_ip}:6443..."
      for i in $(seq 1 60); do
        curl -sk https://${local.server_ip}:6443/readyz >/dev/null 2>&1 && break
        echo "  attempt $i/60..."
        sleep 10
      done
      mkdir -p ~/.kube
      ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        ${var.vm_user}@${local.server_ip} \
        "sudo cat /etc/rancher/k3s/k3s.yaml" \
        | sed "s/127.0.0.1/${local.server_ip}/g" \
        | sed 's/: default$/: k3s/g' \
        > ~/.kube/k3s-config
      chmod 600 ~/.kube/k3s-config
      echo "Kubeconfig saved to ~/.kube/k3s-config"
      echo "  export KUBECONFIG=~/.kube/k3s-config"
    EOT
  }
}

# ──────────────────────────────────────────────
# MetalLB — L2 load balancer for external LAN IPs
# ──────────────────────────────────────────────

resource "null_resource" "metallb" {
  count      = var.metallb_enabled ? 1 : 0
  depends_on = [null_resource.kubeconfig]

  triggers = {
    ip_range = var.metallb_ip_range
    version  = var.metallb_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=~/.kube/k3s-config

      echo "Installing MetalLB ${var.metallb_version}..."
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${var.metallb_version}/config/manifests/metallb-native.yaml

      echo "Waiting for MetalLB controller..."
      kubectl rollout status deployment/controller -n metallb-system --timeout=120s

      echo "Applying MetalLB L2 address pool (${var.metallb_ip_range})..."
      cat <<'MANIFEST' | kubectl apply -f -
${templatefile("${path.module}/templates/metallb-config.yaml.tftpl", {
  ip_range = var.metallb_ip_range
})}
MANIFEST

      echo "MetalLB installed successfully."
    EOT
  }
}

# ──────────────────────────────────────────────
# Ingress NGINX controller
# ──────────────────────────────────────────────

resource "null_resource" "ingress_nginx" {
  count      = var.ingress_nginx_enabled ? 1 : 0
  depends_on = [null_resource.metallb]

  triggers = {
    version = var.ingress_nginx_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=~/.kube/k3s-config

      echo "Installing ingress-nginx ${var.ingress_nginx_version}..."
      kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${var.ingress_nginx_version}/deploy/static/provider/cloud/deploy.yaml

      echo "Waiting for ingress-nginx controller..."
      kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=180s

      echo "Ingress-NGINX external IP:"
      kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "(pending)"
      echo ""
      echo "Ingress-NGINX installed successfully."
    EOT
  }
}
