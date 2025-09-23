#cloud-config
write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          enp1s0:
            dhcp4: false
            addresses:
              - ${INSTANCE_IP}/24
            routes:
              - to: default
                via: 192.168.122.1
            nameservers:
              addresses: [192.168.122.1, 8.8.8.8, 1.1.1.1]
  - path: /opt/start-n8n.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      export NVM_DIR="/home/ubuntu/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      exec n8n

package_update: false
package_upgrade: false

packages:
  - curl
  - libcap2-bin

users:
  - name: ubuntu
    groups: users, admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    plain_text_passwd: ubuntu
    lock_passwd: false
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY}

runcmd:
  # You are root now
  # --- Wait for network connectivity ---
  - |
    echo "Applying static network configuration..."
    sudo netplan apply

    echo "Waiting for network connectivity..."
    COUNT=0
    while [ $COUNT -lt 5 ]
    do
      if ping -c 1 google.com &> /dev/null; then
        echo "Network is up. Continuing..."
        break
      else
        echo "Network is not yet available. Waiting 10 seconds..."
        sleep 10
      fi
      COUNT=$((COUNT+1))
    done
    
    if [ $COUNT -eq 5 ]; then
      echo "Failed to connect to the network after 5 attempts. Exiting."
      exit 1
    fi

  # --- Installation of NVM, Node.js and n8n ---
  - |
    sudo -i -u ubuntu bash <<'EOF'
    echo "Installing NVM (Node Version Manager)..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Load NVM into current session
    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    nvm --version

    echo "Installing latest LTS Node.js version..."
    nvm install --lts
    node --version
    npm --version

    echo "Installing n8n globally..."
    npm install -g n8n

    echo "Creating configuration file for n8n..."
    mkdir -p ~/.n8n

    cat <<EOT >> ~/.n8n/.env
    WEBHOOK_URL=https://${DOMAIN}
    WEBHOOK_TUNNEL_URL=https://${DOMAIN}
    N8N_HOST=0.0.0.0
    N8N_PORT=80
    N8N_EMAIL_MODE=smtp
    N8N_SMTP_HOST=smtp.emaillabs.net.pl
    EOT

    EOF

  # --- Configure and start n8n as a systemd service as 'root' user ---
  - |
    echo "Configuring n8n systemd service..."

    # Find the paths to node and n8n binaries within the ubuntu user's nvm installation
    N8N_PATH=$(sudo -i -u ubuntu bash -c 'source ~/.nvm/nvm.sh && which n8n')
    NODE_PATH=$(sudo -i -u ubuntu bash -c 'source ~/.nvm/nvm.sh && which node')

    # Grant Node.js binary the capability to bind to privileged ports
    echo "Granting node binary permissions to use port 80..."
    sudo setcap 'cap_net_bind_service=+ep' "$NODE_PATH"

    # Create the systemd service file for n8n
    sudo cat <<EOT > /etc/systemd/system/n8n.service
    [Unit]
    Description=n8n workflow automation tool
    After=network.target

    [Service]
    Type=simple
    User=ubuntu
    Group=ubuntu
    WorkingDirectory=/home/ubuntu/.n8n
    EnvironmentFile=/home/ubuntu/.n8n/.env
    ExecStart=/opt/start-n8n.sh
    Restart=on-failure
    RestartSec=5s

    [Install]
    WantedBy=multi-user.target
    EOT

    echo "Reloading systemd, enabling and starting n8n service..."
    sudo systemctl daemon-reload
    sudo systemctl enable n8n
    sudo systemctl start n8n
    sudo systemctl status n8n

