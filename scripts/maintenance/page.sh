# scripts/maintenance/page.sh
#!/bin/bash

setup_maintenance_page() {
    local domain=$1
    local page_path="/var/www/${domain}/maintenance/index.html"
    
    cat > "$page_path" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Site Maintenance</title>
    <style>
        :root {
            --primary: #2196f3;
            --secondary: #ff9800;
            --text: #333;
            --bg: #f5f5f5;
            --card-bg: #ffffff;
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
            line-height: 1.6;
            background: var(--bg);
            color: var(--text);
            display: flex;
            min-height: 100vh;
            align-items: center;
            justify-content: center;
            padding: 1rem;
        }

        .maintenance-container {
            background: var(--card-bg);
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 2rem;
            max-width: 600px;
            width: 100%;
            text-align: center;
        }

        .maintenance-icon {
            width: 80px;
            height: 80px;
            margin: 0 auto 1.5rem;
            animation: pulse 2s infinite;
        }

        .progress-container {
            margin: 2rem 0;
            background: var(--bg);
            border-radius: 10px;
            padding: 1rem;
        }

        .progress-bar {
            background: var(--bg);
            height: 10px;
            border-radius: 5px;
            overflow: hidden;
            margin: 1rem 0;
        }

        .progress-fill {
            height: 100%;
            background: var(--primary);
            width: 0%;
            transition: width 1s ease;
            border-radius: 5px;
        }

        .time-container {
            display: flex;
            justify-content: center;
            gap: 1rem;
            margin: 1.5rem 0;
        }

        .time-block {
            background: var(--bg);
            padding: 0.5rem 1rem;
            border-radius: 4px;
            min-width: 80px;
        }

        .time-value {
            font-size: 1.5rem;
            font-weight: bold;
            color: var(--primary);
        }

        .time-label {
            font-size: 0.8rem;
            color: var(--text-light);
            text-transform: uppercase;
        }

        .status-message {
            margin: 1rem 0;
            font-style: italic;
        }

        .contact-info {
            margin-top: 2rem;
            padding-top: 1rem;
            border-top: 1px solid var(--bg);
            font-size: 0.9rem;
        }

        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.05); }
            100% { transform: scale(1); }
        }

        @media (max-width: 480px) {
            .time-container {
                flex-wrap: wrap;
            }
            
            .time-block {
                min-width: 60px;
            }
        }
    </style>
</head>
<body>
    <div class="maintenance-container">
        <svg class="maintenance-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"/>
            <line x1="12" y1="16" x2="12" y2="16"/>
            <line x1="12" y1="8" x2="12" y2="12"/>
        </svg>

        <h1>Site Maintenance</h1>
        <p>We're currently performing scheduled maintenance to improve our services.</p>

        <div class="progress-container">
            <div class="progress-bar">
                <div class="progress-fill" id="progressBar"></div>
            </div>
            <div class="status-message" id="statusMessage">
                Maintenance in progress...
            </div>
        </div>

        <div class="time-container">
            <div class="time-block">
                <div class="time-value" id="hours">00</div>
                <div class="time-label">Hours</div>
            </div>
            <div class="time-block">
                <div class="time-value" id="minutes">00</div>
                <div class="time-label">Minutes</div>
            </div>
            <div class="time-block">
                <div class="time-value" id="seconds">00</div>
                <div class="time-label">Seconds</div>
            </div>
        </div>

        <div class="contact-info">
            <p>For urgent matters, please contact:</p>
            <p><a href="mailto:{{CONTACT_EMAIL}}">{{CONTACT_EMAIL}}</a></p>
        </div>
    </div>

    <script>
        function updateMaintenanceStatus() {
            fetch('/maintenance/status/maintenance.json')
                .then(response => response.json())
                .then(data => {
                    const now = Math.floor(Date.now() / 1000);
                    const timeLeft = data.end_time - now;
                    const progress = ((now - data.start_time) / (data.end_time - data.start_time)) * 100;
                    
                    if (timeLeft > 0) {
                        updateTimer(timeLeft);
                        updateProgress(progress);
                        document.getElementById('statusMessage').textContent = data.message;
                    } else {
                        window.location.reload();
                    }
                })
                .catch(error => console.error('Error:', error));
        }

        function updateTimer(timeLeft) {
            const hours = Math.floor(timeLeft / 3600);
            const minutes = Math.floor((timeLeft % 3600) / 60);
            const seconds = timeLeft % 60;

            document.getElementById('hours').textContent = String(hours).padStart(2, '0');
            document.getElementById('minutes').textContent = String(minutes).padStart(2, '0');
            document.getElementById('seconds').textContent = String(seconds).padStart(2, '0');
        }

        function updateProgress(progress) {
            document.getElementById('progressBar').style.width = `${Math.min(100, progress)}%`;
        }

        // Update every second
        setInterval(updateMaintenanceStatus, 1000);
        updateMaintenanceStatus();
    </script>
</body>
</html>
EOF

    # Replace placeholders
    sed -i "s/{{CONTACT_EMAIL}}/${MAINTENANCE_CONTACT_EMAIL}/" "$page_path"
}
