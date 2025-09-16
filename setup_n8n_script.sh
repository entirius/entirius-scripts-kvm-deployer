#!/bin/bash

# setup-n8n.sh - Configure n8n for specific client
# Usage: /opt/setup-n8n.sh <client_name> [domain]

set -e

CLIENT_NAME="$1"
DOMAIN="${2:-yourdomain.com}"

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client_name> [domain]"
    exit 1
fi

echo "Setting up n8n for client: $CLIENT_NAME"

# Create systemd service file from template
echo "Creating systemd service file..."
sed "s/CLIENT_NAME/$CLIENT_NAME/g; s/DOMAIN/$DOMAIN/g" \
    /opt/n8n.service.template > /etc/systemd/system/n8n.service

# Create nginx configuration from template
echo "Creating nginx configuration..."
sed "s/CLIENT_NAME/$CLIENT_NAME/g; s/DOMAIN/$DOMAIN/g" \
    /opt/nginx-n8n.conf.template > /etc/nginx/sites-available/${CLIENT_NAME}-n8n

# Enable nginx site
ln -sf /etc/nginx/sites-available/${CLIENT_NAME}-n8n \
       /etc/nginx/sites-enabled/

# Test nginx configuration
nginx -t

# Setup n8n user and directories
echo "Setting up n8n user and directories..."
mkdir -p /home/n8n/.n8n
mkdir -p /home/n8n/.n8n/nodes
mkdir -p /var/log/n8n

# Set proper ownership
chown -R n8n:n8n /home/n8n
chown -R n8n:n8n /var/log/n8n

# Create n8n environment file
cat > /home/n8n/.n8n/.env << EOF
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=https://${CLIENT_NAME}-n8n.${DOMAIN}/
N8N_USER_FOLDER=/home/n8n/.n8n
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=file
N8N_LOG_FILE=/home/n8n/.n8n/n8n.log
NODE_ENV=production
CLIENT_NAME=${CLIENT_NAME}
EOF

chown n8n:n8n /home/n8n/.n8n/.env

# Create log rotation configuration
cat > /etc/logrotate.d/n8n << EOF
/home/n8n/.n8n/n8n.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 n8n n8n
    postrotate
        systemctl reload n8n > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/${CLIENT_NAME}-n8n.*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 www-data www-data
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# Initialize n8n database as n8n user
echo "Initializing n8n..."
sudo -u n8n n8n --version > /home/n8n/.n8n/version.txt

# Enable and start services
echo "Enabling and starting services..."
systemctl daemon-reload
systemctl enable n8n
systemctl start n8n

# Wait for n8n to start
echo "Waiting for n8n to start..."
sleep 10

# Check if n8n is running
if systemctl is-active --quiet n8n; then
    echo "✅ n8n service started successfully"
else
    echo "❌ n8n service failed to start"
    systemctl status n8n
    exit 1
fi

# Reload nginx to apply new configuration
systemctl reload nginx

# Check if nginx configuration is valid
if nginx -t 2>/dev/null; then
    echo "✅ nginx configuration is valid"
else
    echo "❌ nginx configuration has errors"
    nginx -t
    exit 1
fi

# Create startup script for manual management
cat > /home/n8n/manage-n8n.sh << 'EOF'
#!/bin/bash

case "$1" in
    start)
        sudo systemctl start n8n
        echo "n8n started"
        ;;
    stop)
        sudo systemctl stop n8n
        echo "n8n stopped"
        ;;
    restart)
        sudo systemctl restart n8n
        echo "n8n restarted"
        ;;
    status)
        sudo systemctl status n8n
        ;;
    logs)
        sudo journalctl -u n8n -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
EOF

chmod +x /home/n8n/manage-n8n.sh
chown n8n:n8n /home/n8n/manage-n8n.sh

# Summary
echo ""
echo "🎉 n8n setup completed for client: $CLIENT_NAME"
echo ""
echo "Service Information:"
echo "  Service name: n8n"
echo "  Config file: /etc/system