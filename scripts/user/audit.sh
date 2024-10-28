# scripts/user/audit.sh
#!/bin/bash

audit_users() {
    local audit_file="/var/log/multisite-server/user_audit.log"
    
    {
        echo "=== User Audit Report ==="
        echo "Date: $(date)"
        echo
        
        echo "=== System Users ==="
        getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1, $3, $6, $7}'
        echo
        
        echo "=== Site Users ==="
        getent passwd | grep "^site_" | awk -F: '{print $1, $3, $6, $7}'
        echo
        
        echo "=== Sudo Users ==="
        getent group sudo | cut -d: -f4
        echo
        
        echo "=== SSH Access ==="
        for user in $(getent passwd | awk -F: '$7 != "/usr/sbin/nologin" {print $1}'); do
            echo "User: $user"
            if [[ -f "/home/${user}/.ssh/authorized_keys" ]]; then
                echo "SSH Keys:"
                cat "/home/${user}/.ssh/authorized_keys"
            else
                echo "No SSH keys"
            fi
            echo
        done
        
    } > "$audit_file"
    
    log_message "INFO" "User audit completed. Report saved to ${audit_file}"
}