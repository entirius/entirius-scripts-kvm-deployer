# Installation Requirements for entirius-scripts-kvm-deployer

## System Requirements

### Operating System
- **Ubuntu 24.04** (host with KVM/libvirt)
- Internet access for downloading packages

### Required Tools and Packages

#### Basic System Packages
```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst guestfs-tools gettext-base
```

#### Detailed Package Requirements:
- **qemu-kvm** - main KVM virtualization platform
- **libvirt-daemon-system** - virtual machine management daemon
- **virtinst** - virtual machine installation tools (`virt-install`)
- **guestfs-tools** - VM image modification tools (`virt-customize`)
- **gettext-base** - contains `envsubst` for template processing

#### User Permissions
```bash
sudo usermod -a -G libvirt $(whoami)
# Log out and log back in or run:
newgrp libvirt
```

### Ubuntu Cloud Base Image
```bash
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
```

### SSH Keys
SSH key is required for access to created virtual machines:
```bash
# If you don't have SSH keys (using ED25519 according to ADR-018):
ssh-keygen -t ed25519 -C "your-email@example.com"
```

## Environment Configuration

### Storage Paths
- **Default VM path**: `/var/lib/libvirt/images`
- **Working files**: current working directory

### Required Permissions
- User must belong to the `libvirt` group
- Access to `sudo` for `virt-customize` operations
- Write permissions in `/var/lib/libvirt/images`

### Network Configuration
- Libvirt `default` network must be active
- Uses NAT/bridge networking by default

## Project Files

### Executable Scripts
After downloading files, set executable permissions:
```bash
chmod +x create_template_script.sh n8n-deploy.sh setup_n8n_script.sh
```

### File Structure
```
entirius-scripts-kvm-deployer/
├── create_template_script.sh          # VM template creation
├── n8n-deploy.sh                     # Client instance deployment
├── n8n-deploy.config.example         # Configuration file example
├── setup_n8n_script.sh              # n8n configuration
├── templates/
│   └── n8n/
│       ├── user_data_template.txt    # cloud-init template
│       ├── n8n_service_template.txt  # systemd service template
│       └── nginx_config_template.txt # nginx configuration template
└── ubuntu-24.04-server-cloudimg-amd64.img  # Ubuntu base image (optional)
```

## Configuration Parameters

### Configuration in `n8n-deploy.config` file:

Copy and edit the configuration file:
```bash
cp n8n-deploy.config.example n8n-deploy.config
vim n8n-deploy.config
```

Available configuration parameters:
```bash
# Domain configuration
DOMAIN="yourdomain.com"           # Your domain

# VM configuration
TEMPLATE_IMAGE="n8n-template.img" # Template image path
VM_STORAGE_PATH="/var/lib/libvirt/images" # VM storage location
VM_MEMORY=1024                    # RAM memory in MB
VM_VCPUS=1                       # Number of CPUs

# SSH configuration
SSH_KEY_FILE="$HOME/.ssh/id_ed25519.pub" # Path to SSH public key
```

## System Resources

### VM Specifications
- **Memory**: 1024 MB (default, configurable)
- **CPU**: 1 vCPU (default, configurable)
- **Disk**: ~2-3GB based on template size
- **Network**: Bridge/NAT (default libvirt network)

### Disk Requirements
- **VM Template**: ~2-3GB
- **Each client instance**: ~2-3GB
- **Working space**: additional 1GB for temporary files

## Software Components in VM

### Automatically installed in template:
- **Node.js 20.x** - runtime environment for n8n
- **n8n** - workflow automation platform
- **PM2** - Node.js process manager
- **nginx** - web server/reverse proxy
- **System packages**: curl, wget, gnupg

### Security configurations:
- **UFW firewall** - ports 22, 80, 443
- **SSH keys** - key-based authentication only
- **nginx security headers** - X-Frame-Options, CSP
- **Service isolation** - dedicated `n8n` user

## Installation Verification

### Requirements check:
```bash
# Check KVM
kvm-ok

# Check libvirt
sudo systemctl status libvirtd

# Check tools
which virt-install virt-customize envsubst

# Check network
sudo virsh net-list --all
```

### Basic functionality test:
```bash
# VM list
virsh list --all

# DHCP network information
virsh net-dhcp-leases default
```

## WebVirtCloud Integration

The system is fully compatible with WebVirtCloud for centralized management:
- **Automatic VM discovery** - all VMs will appear with proper naming
- **Console access** - VNC console through web interface
- **Power management** - start/stop/restart through WebVirtCloud
- **Monitoring** - resource usage monitoring

## Support and Troubleshooting

### System logs:
- **Cloud-init**: `/var/log/cloud-init-output.log` (in VM)
- **n8n service**: `sudo journalctl -u n8n -f` (in VM)
- **nginx**: `/var/log/nginx/` (in VM)

### Diagnostics:
- **VM status**: `virsh list --all`
- **VM console**: `virsh console vm-name`
- **IP address**: `virsh net-dhcp-leases default`