#!/bin/bash

# n8n-create-template.sh - Creates n8n template VM
# Usage: ./n8n-create-template.sh

set -e

# Load configuration
if [ -f "n8n-deploy.config" ]; then
    source n8n-deploy.config
else
    echo "Error: Configuration file n8n-deploy.config not found!"
    exit 1
fi

BASE_IMAGE="$VM_STORAGE_PATH/ubuntu-24.04-server-cloudimg-amd64.img"
TEMPLATE_IMAGE="$VM_STORAGE_PATH/n8n-template.img"

echo "Creating n8n template VM..."

# Check if base image exists
if [ ! -f "$BASE_IMAGE" ]; then
    echo "Error: Base image $BASE_IMAGE not found!"
    echo "Download it with: wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    exit 1
fi

# Check if template files exist
for file in templates/n8n/n8n_service_template.txt templates/n8n/nginx_config_template.txt setup_n8n_script.sh; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file $file not found!"
        exit 1
    fi
done

# Copy base image to template
echo "Copying base image to template..."
cp "$BASE_IMAGE" "$TEMPLATE_IMAGE"

# Customize the template with virt-customize
echo "Installing packages and configuring template..."
echo "This may take 5-10 minutes..."

sudo virt-customize -a "$TEMPLATE_IMAGE" \
    --update \
    --install nginx,curl,wget,gnupg \
    --run-command 'curl -fsSL https://deb.nodesource.com/setup_20.x | bash -' \
    --install nodejs \
    --run-command 'npm install -g n8n pm2' \
    --run-command 'useradd -m -s /bin/bash n8n' \
    --run-command 'systemctl enable nginx' \
    --copy-in templates/n8n/n8n_service_template.txt:/opt/n8n_service_template.txt \
    --copy-in templates/n8n/nginx_config_template.txt:/opt/nginx_config_template.txt \
    --copy-in setup_n8n_script.sh:/opt/setup_n8n_script.sh \
    --chmod 0755:/opt/setup_n8n_script.sh \
    --run-command 'rm -rf /etc/nginx/sites-enabled/default' \
    --run-command 'mkdir -p /home/n8n/.n8n' \
    --run-command 'chown -R n8n:n8n /home/n8n' \
    --run-command 'apt-get clean'

echo "Template created successfully: $TEMPLATE_IMAGE"
echo "Template size: $(du -h $TEMPLATE_IMAGE | cut -f1)"
echo ""
echo "You can now deploy client instances with:"
echo "./n8n-deploy.sh <client-name>"