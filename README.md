# K3s Cluster on Proxmox — Terraform

Provisions 3 Fedora VMs on Proxmox VE and bootstraps a K3s cluster
(1 server + 2 agents) fully automatically via cloud-init and a pre-shared token.
After `terraform apply`, kubeconfig is fetched to `~/.kube/k3s-config` automatically.

## Prerequisites

1. **Proxmox API token** — Create one in Datacenter → Permissions → API Tokens
2. **Fedora Cloud image template** — Download and import:
   ```bash
   # On your Proxmox host:
   wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2

   qm create 9000 --name fedora-cloud --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
   qm importdisk 9000 Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2 local-lvm
   qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
   qm set 9000 --ide2 local-lvm:cloudinit
   qm set 9000 --boot c --bootdisk scsi0
   qm set 9000 --serial0 socket --vga serial0
   qm set 9000 --agent enabled=1
   qm template 9000
   ```
3. **Snippets enabled** on the `local` datastore (Datacenter → Storage → local → Content → add "Snippets")

## Usage

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Generate a cluster token and add it to terraform.tfvars
echo "k3s_token = \"$(openssl rand -hex 32)\"" >> terraform.tfvars

# 3. Deploy — VMs are created, K3s installs via cloud-init, kubeconfig is fetched automatically
terraform init
terraform plan
terraform apply

# 4. Use the cluster
export KUBECONFIG=~/.kube/k3s-config
kubectl get nodes
```

> **Note:** Cloud-init installs K3s after the VM boots. Terraform will poll the API
> for up to 10 minutes waiting for the server to be ready before fetching kubeconfig.

## File Structure

```
├── main.tf                        # Provider, cloud-init snippets, VM resources, kubeconfig fetch
├── variables.tf                   # All input variables with defaults
├── locals.tf                      # VM definitions map
├── outputs.tf                     # IPs, SSH commands, kubeconfig helper
├── terraform.tfvars.example       # Example config (copy → terraform.tfvars)
└── templates/
    └── cloud-init-user.yaml.tftpl # Cloud-init: OS prep + K3s install (server & agents)
```

## Customization

- **Change VM count**: Edit `locals.tf` to add/remove entries from the `vms` map
- **Pin K3s version**: Add `INSTALL_K3S_VERSION=v1.30.2+k3s1` to the `curl` commands in the cloud-init template
- **Re-enable Traefik**: Remove `--disable traefik` from the cloud-init template
- **Add storage**: Extend `main.tf` with additional `disk` blocks for persistent volumes
