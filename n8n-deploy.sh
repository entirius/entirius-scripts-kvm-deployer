#!/bin/bash

# n8n-deploy.sh - Deploy n8n instance for a specific client
# Usage: ./n8n-deploy.sh <client-name>

set -e

# Configuration
DOMAIN="yourdomain.com"
TEMPLATE_IMAGE="n8n-template.img"
VM_STORAGE_PATH="/var/lib/libvirt/images"
VM_MEMORY=1024
VM_VCPUS=1

CLIENT_NAME="$1"

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client_name>"
    echo "Example: $0 client1"
    exit 1
fi

# Validate client name (alphanumeric and hyphens only)
if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo "Error: Client name must contain only letters, numbers, and hyphens"
    exit 1
fi

VM_NAME="${CLIENT_NAME}-n8n"
VM_DISK_PATH="${VM_STORAGE_PATH}/${VM_NAME}.qcow2"

echo "Deploying n8n instance for client: $CLIENT_NAME"
echo "VM Name: $VM_NAME"
echo "Domain: ${VM_NAME}.${DOMAIN}"

# Check if template exists
if [ ! -f "$TEMPLATE_IMAGE" ]; then
    echo "Error: Template image $TEMPLATE_IMAGE not found!"
    echo "Create it first with: ./create-template.sh"
    exit 1
fi

# Check if VM already exists
if virsh list --all | grep -q "$VM_NAME"; then
    echo "Error: VM $VM_NAME already exists!"
    echo "Remove it first with: virsh destroy $VM_NAME && virsh undefine $VM_NAME --remove-all-storage"
    exit 1
fi

# Check if SSH key exists
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "Error: SSH public key not found at $SSH_KEY_FILE"
    echo "Generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

SSH_KEY="$(cat $SSH_KEY_FILE)"

# Export variables for envsubst
export CLIENT_NAME DOMAIN SSH_KEY

echo "Generating cloud-init configuration..."
envsubst < templates/n8n/user_data_template.txt > "/tmp/${VM_NAME}-user-data.yaml"

echo "Copying template to VM disk..."
sudo cp "$TEMPLATE_IMAGE" "$VM_DISK_PATH"
sudo chown libvirt-qemu:kvm "$VM_DISK_PATH"

echo "Creating VM..."
virt-install \
    --name "$VM_NAME" \
    --memory $VM_MEMORY \
    --vcpus $VM_VCPUS \
    --disk path="$VM_DISK_PATH",format=qcow2 \
    --import \
    --cloud-init user-data="/tmp/${VM_NAME}-user-data.yaml" \
    --network network=default \
    --graphics vnc,listen=0.0.0.0 \
    --noautoconsole \
    --os-variant ubuntu24.04

echo ""
echo "✅ VM $VM_NAME created successfully!"
echo ""
echo "VM Details:"
echo "  Name: $VM_NAME"
echo "  Memory: ${VM_MEMORY}MB"
echo "  CPUs: $VM_VCPUS"
echo "  Disk: $VM_DISK_PATH"
echo ""
echo "Access Information:"
echo "  n8n Web UI: http://${VM_NAME}.${DOMAIN} (after VM boots)"
echo "  Direct access: http://[VM_IP]:5678"
echo "  SSH: ssh ubuntu@[VM_IP]"
echo ""
echo "Monitoring:"
echo "  VM status: virsh list"
echo "  Console: virsh console $VM_NAME"
echo "  VNC: virsh vncdisplay $VM_NAME"
echo ""
echo "The VM is starting up. n8n will be available in 2-3 minutes."

# Cleanup
rm "/tmp/${VM_NAME}-user-data.yaml"

echo ""
echo "To get VM IP address: virsh net-dhcp-leases default"