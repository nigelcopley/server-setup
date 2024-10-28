# setup.sh - Main setup script
#!/bin/bash

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
if [[ ! -f "${SCRIPT_DIR}/config.sh" ]]; then
    echo "Error: Configuration file not found!"
    exit 1
fi
source "${SCRIPT_DIR}/config.sh"

# Load all function scripts
for script in "${SCRIPT_DIR}/scripts/"*.sh; do
    source "$script"
done

# Initialize logging
setup_logging

# Main execution
main() {
    log_message "Starting server setup..."
    
    # Verify root privileges
    check_root
    
    # System updates and basic setup
    update_system
    setup_firewall
    
    # Process each domain
    for domain_entry in "${domains[@]}"; do
        setup_site "${domain_entry}"
    done
    
    # Final configurations and service restarts
    finalize_setup
    
    log_message "Setup completed successfully!"
}

main "$@"