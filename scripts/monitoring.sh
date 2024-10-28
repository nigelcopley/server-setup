# scripts/monitoring.sh
#!/bin/bash

setup_monitoring() {
    local domain=$1
    
    # Install monitoring tools
    apt-get install -y prometheus-node-exporter

    # Create monitoring directory
    mkdir -p "/var/www/${domain}/monitoring"

    # Setup basic status page
    cat > "/var/www/${domain}/monitoring/status.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Server Status</title>
    <meta http-equiv="refresh" content="60">
    <style>
        .status { padding: 10px; margin: 5px; }
        .ok { background: #dff0d8; }
        .error { background: #f2dede; }
    </style>
</head>
<body>
    <div id="status"></div>
    <script>
        fetch('/monitoring/status.json')
            .then(response => response.json())
            .then(data => {
                const statusDiv = document.getElementById('status');
                Object.entries(data).forEach(([service, status]) => {
                    const div = document.createElement('div');
                    div.className = 'status ' + (status ? 'ok' : 'error');
                    div.textContent = service + ': ' + (status ? 'OK' : 'Error');
                    statusDiv.appendChild(div);
                });
            });
    </script>
</body>
</html>
EOF

    # Setup status check script
    cat > "/var/www/${domain}/monitoring/check_status.sh" <<EOF
#!/bin/bash
check_service() {
    systemctl is-active --quiet \$1 && echo "true" || echo "false"
}

cat > "/var/www/${domain}/monitoring/status.json" <<EOJ
{
    "nginx": \$(check_service nginx),
    "php-fpm": \$(check_service php*-fpm),
    "database": \$(check_service mysql postgresql),
    "fail2ban": \$(check_service fail2ban)
}
EOJ
EOF

    chmod +x "/var/www/${domain}/monitoring/check_status.sh"

    # Add cron job for status updates
    echo "*/5 * * * * /var/www/${domain}/monitoring/check_status.sh" | crontab -
}