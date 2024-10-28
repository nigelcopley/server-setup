# scripts/notifications/templates.sh
#!/bin/bash

setup_notification_templates() {
    mkdir -p /etc/multisite-server/notifications/templates
    
    # Email templates
    create_email_templates
    
    # Slack templates
    create_slack_templates
    
    # Discord templates
    create_discord_templates
}

create_email_templates() {
    # Base email template
    cat > "/etc/multisite-server/notifications/templates/email_base.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .content {
            background: white;
            padding: 20px;
            border-radius: 5px;
            border: 1px solid #ddd;
        }
        .footer {
            margin-top: 20px;
            font-size: 12px;
            color: #666;
        }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        .info { color: #0dcaf0; }
        .success { color: #198754; }
    </style>
</head>
<body>
    <div class="header">
        <h2>{{TITLE}}</h2>
    </div>
    <div class="content">
        <p>{{MESSAGE}}</p>
        <div class="details">
            <p><strong>Service:</strong> {{SERVICE}}</p>
            <p><strong>Domain:</strong> {{DOMAIN}}</p>
            <p><strong>Time:</strong> {{TIMESTAMP}}</p>
        </div>
    </div>
    <div class="footer">
        <p>Notification ID: {{NOTIFICATION_ID}}</p>
        <p>This is an automated message, please do not reply.</p>
    </div>
</body>
</html>
EOF

    # Create event-specific templates
    for event_type in error warning info success; do
        cp "/etc/multisite-server/notifications/templates/email_base.html" \
           "/etc/multisite-server/notifications/templates/email_${event_type}.html"
    done
}