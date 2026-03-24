#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# install-k3s.sh — Bootstrap K3s on Terraform-provisioned VMs
#
# Usage:
#   ./install-k3s.sh <server_ip> <agent1_ip> <agent2_ip> [ssh_user]
#
# This script:
#   1. Installs K3s server on the first node
#   2. Retrieves the node token
#   3. Joins agent nodes to the cluster
#   4. Fetches kubeconfig to your local machine
# ─────────────────────────────────────────────────────────
set -euo pipefail

SERVER_IP="${1:?Usage: $0 <server_ip> <agent1_ip> <agent2_ip> [ssh_user]}"
AGENT1_IP="${2:?Missing agent1 IP}"
AGENT2_IP="${3:?Missing agent2 IP}"
SSH_USER="${4:-fedora}"
K3S_VERSION="${K3S_VERSION:-}"  # Leave empty for latest, or set e.g. "v1.30.2+k3s1"

VERSION_FLAG=""
if [[ -n "$K3S_VERSION" ]]; then
  VERSION_FLAG="INSTALL_K3S_VERSION=$K3S_VERSION"
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
err()   { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

wait_for_ssh() {
  local host=$1
  info "Waiting for SSH on $host..."
  for i in $(seq 1 30); do
    ssh $SSH_OPTS "$SSH_USER@$host" "echo ok" &>/dev/null && return 0
    sleep 5
  done
  err "Timed out waiting for $host"
  return 1
}

# ── Step 1: Install K3s server ──
info "Installing K3s server on $SERVER_IP..."
wait_for_ssh "$SERVER_IP"
ssh $SSH_OPTS "$SSH_USER@$SERVER_IP" "
  sudo hostnamectl set-hostname k3s-server
  curl -sfL https://get.k3s.io | $VERSION_FLAG INSTALL_K3S_EXEC='server' sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --tls-san $SERVER_IP \
    --node-name k3s-server
"
ok "K3s server installed"

# ── Step 2: Get node token ──
info "Retrieving node token..."
NODE_TOKEN=$(ssh $SSH_OPTS "$SSH_USER@$SERVER_IP" "sudo cat /var/lib/rancher/k3s/server/node-token")
ok "Token retrieved"

# ── Step 3: Join agents ──
for AGENT_IP in "$AGENT1_IP" "$AGENT2_IP"; do
  AGENT_NAME="k3s-agent-${AGENT_IP##*.}"
  info "Joining agent $AGENT_NAME ($AGENT_IP)..."
  wait_for_ssh "$AGENT_IP"
  ssh $SSH_OPTS "$SSH_USER@$AGENT_IP" "
    sudo hostnamectl set-hostname $AGENT_NAME
    curl -sfL https://get.k3s.io | $VERSION_FLAG K3S_URL='https://$SERVER_IP:6443' K3S_TOKEN='$NODE_TOKEN' sh -s - \
      --node-name $AGENT_NAME
  "
  ok "Agent $AGENT_NAME joined"
done

# ── Step 4: Verify cluster ──
info "Waiting for nodes to register..."
sleep 10
ssh $SSH_OPTS "$SSH_USER@$SERVER_IP" "sudo kubectl get nodes -o wide"

# ── Step 5: Fetch kubeconfig ──
KUBECONFIG_LOCAL="${HOME}/.kube/k3s-config"
mkdir -p "${HOME}/.kube"
ssh $SSH_OPTS "$SSH_USER@$SERVER_IP" "sudo cat /etc/rancher/k3s/k3s.yaml" \
  | sed "s/127.0.0.1/$SERVER_IP/g" \
  > "$KUBECONFIG_LOCAL"
chmod 600 "$KUBECONFIG_LOCAL"

ok "Cluster ready! Kubeconfig saved to $KUBECONFIG_LOCAL"
echo ""
echo "  export KUBECONFIG=$KUBECONFIG_LOCAL"
echo "  kubectl get nodes"
echo ""
