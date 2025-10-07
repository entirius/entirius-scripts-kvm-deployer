#cloud-config

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - vim
  - git
  - htop
  - net-tools

users:
  - name: ${WEBAPP_USER}
    groups: users, admin
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    plain_text_passwd: ${WEBAPP_PASSWORD}
    lock_passwd: false
    ssh_authorized_keys:
      - ${SSH_PUBLIC_KEY}

runcmd:
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

  # --- System setup ---
  - |
    echo "System setup completed successfully."
    echo "Ubuntu 24.04 instance is ready."
