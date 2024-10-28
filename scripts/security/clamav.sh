# scripts/security/clamav.sh
#!/bin/bash

setup_clamav() {
    if [[ "${INSTALL_CLAMAV}" != "1" ]]; then
        return 0
    fi
    
    log_message "INFO" "Setting up ClamAV..."
    
    # Install ClamAV
    apt-get install -y clamav clamav-daemon
    
    # Stop daemon for initial update
    systemctl stop clamav-freshclam
    systemctl stop clamav-daemon
    
    # Update virus definitions
    freshclam
    
    # Configure ClamAV
    cat > "/etc/clamav/clamd.conf" <<EOF
LocalSocket /var/run/clamav/clamd.ctl
FixStaleSocket true
LocalSocketGroup clamav
LocalSocketMode 666
User clamav
ScanPE true
ScanELF true
DetectPUA true
ScanArchive true
ArchiveBlockEncrypted false
MaxDirectoryRecursion 15
FollowDirectorySymlinks false
FollowFileSymlinks false
ReadTimeout 180
MaxThreads 12
MaxConnectionQueueLength 15
LogSyslog false
LogFacility LOG_LOCAL6
LogClean false
LogVerbose false
DatabaseDirectory /var/lib/clamav
OfficialDatabaseOnly false
EOF
    
    # Setup daily scan
    cat > "/etc/cron.daily/clamscan" <<EOF
#!/bin/bash

# Directory to scan
SCAN_DIR="/var/www"

# Log file
LOG_FILE="/var/log/clamav/daily_scan.log"

# Notification email
NOTIFY_EMAIL="${NOTIFICATION_EMAIL}"

# Start scan
echo "Starting daily scan at \$(date)" > "\${LOG_FILE}"
clamscan -ri "\${SCAN_DIR}" >> "\${LOG_FILE}" 2>&1

# Check if virus was found
VIRUS_FOUND=\$?

# Send notification if virus found
if [ "\${VIRUS_FOUND}" -eq 1 ]; then
    echo "Virus found during daily scan" | \
    mail -s "ClamAV - Virus Detected" "\${NOTIFY_EMAIL}" < "\${LOG_FILE}"
fi

# Rotate logs
find /var/log/clamav -name "daily_scan.log.*" -mtime +30 -delete
EOF
    
    chmod +x /etc/cron.daily/clamscan
    
    # Start services
    systemctl start clamav-freshclam
    systemctl start clamav-daemon
    systemctl enable clamav-freshclam
    systemctl enable clamav-daemon
    
    log_message "INFO" "ClamAV setup completed"
}