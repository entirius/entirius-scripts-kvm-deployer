# n8n KVM Multi-Client Deployment System

This deployment system allows you to quickly create KVM instances with n8n workflow automation for multiple clients using templates and cloud-init automation.

## Features

- **Template-based deployment** - Deploy new client instances in 2-3 minutes
- **Automatic naming** - Each client gets `clientname-n8n` hostname and VM name
- **Native n8n installation** - No Docker required, lightweight setup
- **Nginx reverse proxy** - Professional web server configuration
- **WebVirtCloud compatible** - Works with centralized KVM management
- **Cloud-init automation** - Zero manual configuration required

## Architecture

```
Template VM (n8n-template.img) 
    ↓ 
Client-specific cloud-init config 
    ↓ 
Ready-to-use client VM (client1-n8n, client2-n8n, etc.)
```

## Prerequisites

- Ubuntu 24.04 host with KVM/libvirt
- `virt-install` and `virt-customize` tools
- `envsubst` (from gettext-base package)
- Internet access for downloading packages

## Installation

### 1. Install required tools

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst guestfs-tools gettext-base
sudo usermod -a -G libvirt $(whoami)
# Re-login or run: newgrp libvirt
```

### 2. Download Ubuntu Cloud Image

```bash
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
```

### 3. Deploy the files

Download all files from this repository and place them in your working directory:

- `create-template.sh` - Creates the base template with n8n
- `deploy-client.sh` - Deploys new client instances
- `user-data-template.yaml` - Cloud-init configuration template
- `n8n.service.template` - Systemd service template
- `nginx-n8n.conf.template` - Nginx configuration template
- `setup-n8n.sh` - Client-specific setup script

### 4. Make scripts executable

```bash
chmod +x create-template.sh deploy-client.sh setup-n8n.sh
```

## Configuration

### 1. Edit configuration variables

In `deploy-client.sh`, modify these variables:

```bash
DOMAIN="yourdomain.com"           # Your domain
TEMPLATE_IMAGE="n8n-template.img" # Template image path
VM_STORAGE_PATH="/var/lib/libvirt/images" # VM storage location
```

### 2. SSH Key Setup

Ensure you have SSH key pair generated:

```bash
# If you don't have SSH keys (using ED25519 per ADR-018):
ssh-keygen -t ed25519 -C "your-email@example.com"
```

## Usage

### 1. Create the base template (run once)

```bash
./create-template.sh
```

This process takes 5-10 minutes and creates `n8n-template.img` with:
- Node.js 20.x
- n8n workflow automation
- PM2 process manager
- Nginx web server
- Pre-configured service files

### 2. Deploy client instances

```bash
./deploy-client.sh client1
./deploy-client.sh client2
./deploy-client.sh client3
```

Each deployment takes 2-3 minutes and creates:
- VM named `client1-n8n`
- Hostname `client1-n8n.yourdomain.com`
- n8n accessible at `http://client1-n8n.yourdomain.com`
- Automatic service startup

### 3. Access n8n instances

- **Web Interface**: `http://clientname-n8n.yourdomain.com`
- **Direct access**: `http://vm-ip:5678`
- **SSH access**: `ssh ubuntu@vm-ip`

## VM Specifications

- **Memory**: 1024 MB (adjustable in deploy-client.sh)
- **CPU**: 1 vCPU (adjustable)
- **Disk**: Based on template size (~2-3GB)
- **Network**: Bridge/NAT (default libvirt network)

## File Structure

```
.
├── README.md
├── create-template.sh          # Template creation script
├── deploy-client.sh           # Client deployment script
├── user-data-template.yaml    # Cloud-init template
├── n8n.service.template       # Systemd service template
├── nginx-n8n.conf.template    # Nginx config template
├── setup-n8n.sh             # Post-install configuration script
└── ubuntu-24.04-server-cloudimg-amd64.img  # Base Ubuntu image
```

## WebVirtCloud Integration

The created VMs are fully compatible with WebVirtCloud for centralized management:

1. **VM Discovery**: All VMs will appear in WebVirtCloud with proper naming
2. **Console Access**: VNC console available through web interface  
3. **Power Management**: Start/stop/restart through WebVirtCloud
4. **Monitoring**: Resource usage monitoring

## Customization

### Memory and CPU

Edit `deploy-client.sh`:

```bash
--memory 2048 \     # Change memory allocation
--vcpus 2 \        # Change CPU cores
```

### n8n Configuration

Modify `user-data-template.yaml` to add custom n8n settings:

```yaml
  - path: /home/n8n/.n8n/config
    content: |
      {
        "database": {
          "type": "sqlite",
          "database": "/home/n8n/.n8n/database.sqlite"
        },
        "endpoints": {
          "webhook": "https://${CLIENT_NAME}-n8n.${DOMAIN}/"
        },
        "security": {
          "basicAuth": {
            "active": true,
            "user": "admin",
            "password": "your-password"
          }
        }
      }
```

### Additional Software

Add packages to `user-data-template.yaml`:

```yaml
packages:
  - htop
  - curl
  - wget
  - ufw
  - your-additional-package
```

## Troubleshooting

### Template Creation Issues

```bash
# Check if template was created successfully
ls -la n8n-template.img

# Test template by creating a temporary VM
virt-install --name test-template --import --disk n8n-template.img --memory 512 --noautoconsole
```

### Client Deployment Issues

```bash
# Check VM status
virsh list --all

# View VM console
virsh console clientname-n8n

# Check cloud-init logs inside VM
sudo tail -f /var/log/cloud-init-output.log
```

### Network Issues

```bash
# Check if VM got IP address
virsh net-dhcp-leases default

# Test connectivity
ping clientname-n8n.yourdomain.com
```

### n8n Service Issues

Inside the VM:

```bash
# Check n8n service status
sudo systemctl status n8n

# View n8n logs
sudo journalctl -u n8n -f

# Check nginx status
sudo systemctl status nginx
```

## Security Considerations

1. **Firewall**: UFW is configured to allow only SSH (22), HTTP (80), and HTTPS (443)
2. **SSH Keys**: Only key-based SSH authentication
3. **n8n Security**: Consider enabling basic auth in n8n configuration
4. **Network**: VMs use default libvirt network (NAT)

## Backup Strategy

```bash
# Backup template
cp n8n-template.img n8n-template-backup-$(date +%Y%m%d).img

# Backup client VM
virsh dumpxml clientname-n8n > clientname-n8n.xml
cp /var/lib/libvirt/images/clientname-n8n.qcow2 /backup/location/
```

## Scaling

For large deployments (50+ clients):

1. Consider using automation tools (Ansible, Terraform)
2. Implement monitoring (Prometheus/Grafana)
3. Use shared storage for templates
4. Consider resource quotas and limits

## Support

For issues and questions:

1. Check troubleshooting section
2. Review cloud-init logs
3. Verify template integrity
4. Test with minimal configuration

---

**Note**: This system is designed for internal/development use. For production deployments, consider additional security hardening, monitoring, and backup strategies.