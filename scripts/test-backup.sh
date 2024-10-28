# scripts/test-backup.sh
#!/bin/bash

set -euo pipefail

test_backup() {
    local domain=$1
    local test_dir="/tmp/backup-test-${domain}"
    local backup_config="/var/www/${domain}/config/backup.json"
    
    echo "Testing backup system for ${domain}"
    echo "================================="
    
    # Test backup creation
    echo "Testing backup creation..."
    /usr/local/bin/backup-${domain}.sh "${domain}"
    
    # Create test directory
    mkdir -p "$test_dir"
    
    # Test local storage
    if [[ $(jq -r '.storage.local.enabled' "$backup_config") == "true" ]]; then
        echo -e "\nTesting local storage:"
        local backup_path=$(jq -r '.storage.local.path' "$backup_config")
        ls -lh "${backup_path}"
    fi
    
    # Test S3 storage
    if [[ $(jq -r '.storage.s3.enabled' "$backup_config") == "true" ]]; then
        echo -e "\nTesting S3 storage:"
        local bucket=$(jq -r '.storage.s3.bucket' "$backup_config")
        local path=$(jq -r '.storage.s3.path' "$backup_config")
        aws s3 ls "s3://${bucket}/${path}/"
    fi
    
    # Test Spaces storage
    if [[ $(jq -r '.storage.spaces.enabled' "$backup_config") == "true" ]]; then
        echo -e "\nTesting Spaces storage:"
        local bucket=$(jq -r '.storage.spaces.bucket' "$backup_config")
        local path=$(jq -r '.storage.spaces.path' "$backup_config")
        local region=$(jq -r '.storage.spaces.region' "$backup_config")
        aws s3 ls "s3://${bucket}/${path}/" --endpoint-url "https://${region}.digitaloceanspaces.com"
    fi
    
    # Test restore
    echo -e "\nTesting restore functionality..."
    local latest_backup=$(find "${backup_path}" -type f -name "*.tar.gz" | sort | tail -n1)
    if [[ -n "$latest_backup" ]]; then
        /usr/local/bin/restore-${domain}.sh "${domain}" "$latest_backup" "$test_dir"
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo -e "\nBackup test completed."
}

# Usage check
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 domain"
    exit 1
fi

test_backup "$1"