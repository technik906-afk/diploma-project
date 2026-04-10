#!/bin/bash
# =============================================================================
# Update Ansible inventory with Terraform outputs
# =============================================================================
# Usage: ./scripts/update-inventory.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$PROJECT_DIR/terraform"
INVENTORY="$PROJECT_DIR/ansible/inventory/hosts.ini"

echo "=== Updating Ansible inventory from Terraform outputs ==="

# Get LB public IP
LB_IP=$(cd "$TF_DIR" && terraform output -raw lb_public_ip 2>/dev/null)

if [ -z "$LB_IP" ]; then
    echo "ERROR: Could not get lb_public_ip from Terraform"
    echo "Run 'terraform apply' first in $TF_DIR"
    exit 1
fi

echo "LB Public IP: $LB_IP"

# Update inventory file
sed -i "s/lb-01 ansible_host=.*/lb-01 ansible_host=${LB_IP}/" "$INVENTORY"
sed -i "s/ubuntu@[0-9.]*\"/ubuntu@${LB_IP}\"/g" "$INVENTORY"

echo "=== Inventory updated successfully ==="
echo ""
echo "Verify with:"
echo "  cd $PROJECT_DIR/ansible && ansible all -m ping"
