# scripts/user/monitor.sh
#!/bin/bash

monitor_user_activity() {
    local log_file="/var/log/multisite-server/user_activity.log"
    
    # Monitor sudo usage
    tail -f /var/log/auth.log | grep -i sudo >> "$log_file" &
    
    # Monitor SSH access
    tail -f /var/log/auth.log | grep -i "sshd" >> "$log_file" &
    
    # Monitor failed login attempts
    tail -f /var/log/auth.log | grep -i "failed" >> "$log_file" &
}