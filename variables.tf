# ──────────────────────────────────────────────
# Proxmox connection
# ──────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "Proxmox API URL (e.g. https://pve.example.com:8006)"
  type        = string
}

variable "proxmox_api_token" {
  description = "API token in format: user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (set true for self-signed certs)"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name to deploy VMs on"
  type        = string
  default     = "pve"
}

# ──────────────────────────────────────────────
# VM template & storage
# ──────────────────────────────────────────────

variable "ubuntu_template_vmid" {
  description = "VM ID of the Ubuntu cloud image template"
  type        = number
  default     = 8000
}

variable "vm_datastore" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "snippets_datastore" {
  description = "Datastore that supports snippets (for cloud-init)"
  type        = string
  default     = "local"
}

# ──────────────────────────────────────────────
# Network
# ──────────────────────────────────────────────

variable "network_bridge" {
  description = "Proxmox network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_prefix" {
  description = "IP prefix for VMs (e.g. 10.10.10)"
  type        = string
  default     = "10.10.10"
}

variable "ip_offset" {
  description = "Starting last octet for VM IPs"
  type        = number
  default     = 50
}

variable "cidr" {
  description = "CIDR suffix for IP addresses"
  type        = string
  default     = "/24"
}

variable "gateway" {
  description = "Default gateway"
  type        = string
  default     = "10.10.10.1"
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "dns_domain" {
  description = "DNS search domain for VMs (avoid bare TLDs like 'com' which break pod DNS resolution)"
  type        = string
  default     = "local"
}

# ──────────────────────────────────────────────
# VM sizing
# ──────────────────────────────────────────────

variable "server_cores" {
  description = "CPU cores for K3s server node"
  type        = number
  default     = 2
}

variable "server_memory" {
  description = "RAM (MB) for K3s server node"
  type        = number
  default     = 4096
}

variable "server_disk" {
  description = "Disk size (GB) for K3s server node"
  type        = number
  default     = 40
}

variable "agent_cores" {
  description = "CPU cores for K3s agent nodes"
  type        = number
  default     = 2
}

variable "agent_memory" {
  description = "RAM (MB) for K3s agent nodes"
  type        = number
  default     = 4096
}

variable "agent_disk" {
  description = "Disk size (GB) for K3s agent nodes"
  type        = number
  default     = 40
}

# ──────────────────────────────────────────────
# VM IDs
# ──────────────────────────────────────────────

variable "vmid_offset" {
  description = "Starting VM ID"
  type        = number
  default     = 200
}

# ──────────────────────────────────────────────
# Access
# ──────────────────────────────────────────────

variable "vm_user" {
  description = "Default user created by cloud-init"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to inject"
  type        = list(string)
}

variable "k3s_token" {
  description = "Pre-shared token for K3s cluster (used by server and agents)"
  type        = string
  sensitive   = true
}

# ──────────────────────────────────────────────
# MetalLB
# ──────────────────────────────────────────────

variable "metallb_enabled" {
  description = "Install MetalLB load balancer"
  type        = bool
  default     = true
}

variable "metallb_version" {
  description = "MetalLB version to install"
  type        = string
  default     = "v0.14.9"
}

variable "metallb_ip_range" {
  description = "IP range for MetalLB L2 address pool (e.g. 192.168.0.240-192.168.0.248)"
  type        = string
  default     = "192.168.0.240-192.168.0.248"
}

# ──────────────────────────────────────────────
# Ingress NGINX
# ──────────────────────────────────────────────

variable "ingress_nginx_enabled" {
  description = "Install ingress-nginx controller"
  type        = bool
  default     = true
}

variable "ingress_nginx_version" {
  description = "Ingress-NGINX controller version"
  type        = string
  default     = "v1.12.1"
}
