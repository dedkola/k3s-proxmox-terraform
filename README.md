# K3s Cluster on Proxmox — Terraform

Provisions 3 Ubuntu VMs on Proxmox VE and bootstraps a K3s cluster
(1 server + 2 agents) fully automatically via cloud-init and a pre-shared token.
After `terraform apply`, kubeconfig is fetched to `~/.kube/k3s-config` automatically.

## Prerequisites

1. **Proxmox API token** — Create one in Datacenter → Permissions → API Tokens
2. **Ubuntu Cloud image template** — Download and import:

   ```bash
   # On your Proxmox host:
   wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

   qm create 8000 --memory 2048 --core 2 --name ubuntu-cloud --net0 virtio,bridge=vmbr0
   qm disk import 8000 noble-server-cloudimg-amd64.img local-lvm
   qm set 8000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-8000-disk-0
   qm set 8000 --ide2 local-lvm:cloudinit
   qm set 8000 --boot c --bootdisk scsi0
   qm set 8000 --serial0 socket --vga serial0
   qm template 8000
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

## Important: DNS Domain

The `dns_domain` variable **must** be set to a proper search domain (default: `"local"`).
Without it, Proxmox sets the VM search domain to a bare TLD (e.g. `com`), which causes
Kubernetes pods to resolve `github.com` as `github.com.com` due to `ndots:5` — breaking
HTTPS connectivity from pods.

## File Structure

```
├── main.tf                        # Provider, cloud-init snippets, VM resources, kubeconfig fetch
├── variables.tf                   # All input variables with defaults
├── locals.tf                      # VM definitions map (1 server + 2 agents)
├── outputs.tf                     # IPs, SSH commands, kubeconfig helper
├── terraform.tfvars.example       # Example config (copy → terraform.tfvars)
└── templates/
    └── cloud-init-user.yaml.tftpl # Cloud-init: OS prep + K3s install (server & agents)
```

## Clean up

```bash
# Destroy all Terraform-managed resources
terraform destroy
```

## Customization

- **Change VM count**: Edit `locals.tf` to add/remove entries from the `vms` map
- **Re-enable Traefik**: Remove `--disable traefik` from the K3s server install command in the cloud-init template
- **Add storage**: Extend `main.tf` with additional `disk` blocks for persistent volumes
