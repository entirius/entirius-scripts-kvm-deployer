#!/usr/bin/env bash
set -Eeuo pipefail

# === COLORS AND STYLES ===
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

# === LOGGING FUNCTIONS ===
info() { echo -e "${C_CYAN}${C_BOLD}[INFO]${C_RESET} $1"; }
success() { echo -e "${C_GREEN}${C_BOLD}[SUCCESS]${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}${C_BOLD}[WARNING]${C_RESET} $1"; }
error() { echo -e "${C_RED}${C_BOLD}[ERROR]${C_RESET} $1" >&2; exit 1; }

# === MAIN FUNCTION ===
main() {
    clear
    info "Starting the Ubuntu 24.04 virtual machine creation process..."

    # Check and load configuration
    CONFIG_FILE="ubuntu-deploy.config"
    check_and_source_config

    # Verify system dependencies
    check_dependencies "wget" "qemu-img" "genisoimage" "virt-install" "virsh" "envsubst"

    # Prepare images (download, create VM disk)
    prepare_images

    # Create cloud-init file for automatic configuration
    create_cloud_init_iso

    # Create and start the virtual machine
    create_vm

    # Wait for an IP address and display the summary
    wait_for_ip_and_report

    # Clean up
    cleanup

    success "Deployment completed successfully!"
    echo -e "\nYour Ubuntu 24.04 instance is ready!"
    echo -e "You can log into the machine via SSH: ${C_YELLOW}ssh ${WEBAPP_USER}@${VM_IP}${C_RESET}"
    echo -e "You can access the console with: ${C_YELLOW}virsh console ${VM_NAME}${C_RESET}"
    echo -e "To exit console mode, press ${C_YELLOW}Ctrl+]${C_RESET}\n"
}

# === HELPER FUNCTIONS ===

check_and_source_config() {
    info "Checking configuration file..."
    if [ ! -f "$CONFIG_FILE" ]; then
        error "Configuration file '${CONFIG_FILE}' not found."
    fi
    # shellcheck source=ubuntu-deploy.config
    source "$CONFIG_FILE"

    if [ ! -f "$SSH_KEY_FILE" ]; then
        error "SSH public key file '${SSH_KEY_FILE}' does not exist. Check the path in the configuration."
    fi
    success "Configuration loaded."
}

check_dependencies() {
    info "Checking dependencies..."
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "Required command not found: '$cmd'. Install the package that provides it (e.g., qemu-utils, virtinst, libvirt-clients, genisoimage, gettext-base)."
        fi
    done
    success "All dependencies are met."
}

prepare_images() {
    BASE_IMAGE_PATH="${VM_STORAGE_PATH}/${TEMPLATE_IMAGE}"
    VM_DISK_PATH="${VM_STORAGE_PATH}/${VM_NAME}.qcow2"

    info "Preparing disk images..."

    # Check if the image directory exists
    if [ ! -d "$VM_STORAGE_PATH" ]; then
        warn "Directory '${VM_STORAGE_PATH}' does not exist. Creating it..."
        sudo mkdir -p "$VM_STORAGE_PATH" || error "Failed to create directory '${VM_STORAGE_PATH}'."
    fi

    # Download the base image if it doesn't exist
    if [ ! -f "$BASE_IMAGE_PATH" ]; then
        info "Downloading Ubuntu 24.04 Cloud Image..."
        sudo wget -O "$BASE_IMAGE_PATH" "$BASE_IMAGE_URL" || error "Base image download failed."
        success "Ubuntu 24.04 template image downloaded."
    else
        info "Base Ubuntu 24.04 template image already exists."
    fi

    # Check if a VM with the same name already exists
    if sudo virsh dominfo "${VM_NAME}" &> /dev/null; then
        error "A virtual machine named '${VM_NAME}' already exists. Aborting."
    fi

    # Create the disk for the new VM based on the base image
    info "Creating disk for virtual machine '${VM_NAME}' with size ${VM_DISK_SIZE}..."
    sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE_IMAGE_PATH" "$VM_DISK_PATH" "${VM_DISK_SIZE}" || error "Failed to create qcow2 disk."
    success "Disk images are ready."
}

create_cloud_init_iso() {
    info "Creating cloud-init configuration from template..."
    WORK_DIR=$(mktemp -d)
    USER_DATA_TEMPLATE="templates/ubuntu/user_data_template.yaml.tpl"

    if [ ! -f "$USER_DATA_TEMPLATE" ]; then
        error "User data template file not found at '${USER_DATA_TEMPLATE}'."
    fi

    # Export variables to be used in the template.
    export SSH_PUBLIC_KEY
    SSH_PUBLIC_KEY=$(cat "${SSH_KEY_FILE}")

    # Export all required variables for the template
    export DOMAIN WEBAPP_USER WEBAPP_PASSWORD

    # envsubst will substitute all exported variables in the template
    envsubst '${SSH_PUBLIC_KEY},${DOMAIN},${WEBAPP_USER},${WEBAPP_PASSWORD}' < "${USER_DATA_TEMPLATE}" > "${WORK_DIR}/user-data"

    # Ensure template file is valid
    cloud-init schema --config-file "${WORK_DIR}/user-data" || error "Invalid cloud-init user-data file. Check files in tmp dir: ${WORK_DIR}"

    # meta-data file (remains the same)
    cat <<EOF > "${WORK_DIR}/meta-data"
instance-id: ${VM_NAME}-$(uuidgen | cut -c -8)
local-hostname: ${VM_NAME}
EOF

    SEED_ISO_PATH="${VM_STORAGE_PATH}/${VM_NAME}-seed.iso"
    info "Generating cloud-init ISO image..."
    sudo rm -f "${SEED_ISO_PATH}"
    sudo genisoimage -output "${SEED_ISO_PATH}" -volid cidata -joliet -rock "${WORK_DIR}/user-data" "${WORK_DIR}/meta-data" || error "Failed to generate ISO image."

    # Set permissions for libvirt to read the files
    sudo chmod 644 "${VM_STORAGE_PATH}/${VM_NAME}"*

    success "cloud-init ISO image created successfully."
}

create_vm() {
    info "Creating virtual machine '${VM_NAME}'..."
    sudo virt-install \
        --name "${VM_NAME}" \
        --virt-type kvm \
        --memory "${VM_MEMORY}" \
        --vcpus "${VM_VCPUS}" \
        --os-variant ubuntu24.04 \
        --disk path="${VM_STORAGE_PATH}/${VM_NAME}.qcow2",device=disk,bus=virtio \
        --disk path="${VM_STORAGE_PATH}/${VM_NAME}-seed.iso",device=cdrom \
        --import \
        --network network=default,model=virtio \
        --graphics none \
        --console pty,target_type=serial \
        --serial pty \
        --noautoconsole || error "Failed to create virtual machine."
    success "Virtual machine '${VM_NAME}' has been created and started."
}

# waiting for dhcp
#        --network bridge=virbr0,model=virtio \
# --noautoconsole console does not open automatically after VM creation

wait_for_ip_and_report() {
    info "Waiting for an IP address from DHCP (this may take a minute)..."
    for i in {1..30}; do
        VM_IP=$(sudo virsh domifaddr "${VM_NAME}" | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
        if [ -n "$VM_IP" ]; then
            success "Virtual machine received IP address: ${C_YELLOW}${VM_IP}${C_RESET}"
            return 0
        fi
        echo -n "."
        sleep 5
    done
    echo ""
    error "Failed to get an IP address for machine '${VM_NAME}'. Check your libvirt network configuration."
}

cleanup() {
    info "Cleaning up temporary files..."
    if [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR"
    fi
    success "Cleanup finished."
}


# === SCRIPT EXECUTION ===
main
