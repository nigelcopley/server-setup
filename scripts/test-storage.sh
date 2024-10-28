# scripts/test-storage.sh
#!/bin/bash

set -euo pipefail

test_storage() {
    local domain=$1
    local config_file="/var/www/${domain}/config/backup.json"
    local test_file="/tmp/storage-test-${domain}-$(date +%s)"
    
    echo "Testing storage backends for ${domain}"
    echo "====================================="
    
    # Create test file
    echo "Test content" > "$test_file"
    
    # Test local storage
    if [[ $(jq -r '.storage.local.enabled' "$config_file") == "true" ]]; then
        echo -e "\nTesting local storage:"
        local path=$(jq -r '.storage.local.path' "$config_file")
        
        mkdir -p "$path"
        cp "$test_file" "${path}/test.txt"
        if [[ -f "${path}/test.txt" ]]; then
            echo "✅ Local storage test passed"
            rm "${path}/test.txt"
        else
            echo "❌ Local storage test failed"
        fi
    fi
    
    # Test S3
    if [[ $(jq -r '.storage.s3.enabled' "$config_file") == "true" ]]; then
        echo -e "\nTesting S3 storage:"
        local bucket=$(jq -r '.storage.s3.bucket' "$config_file")
        local path=$(jq -r '.storage.s3.path' "$config_file")
        
        if aws s3 cp "$test_file" "s3://${bucket}/${path}/test.txt"; then
            echo "✅ S3 upload test passed"
            aws s3 rm "s3://${bucket}/${path}/test.txt"
            echo "✅ S3 delete test passed"
        else
            echo "❌ S3 storage test failed"
        fi
    fi
    
    # Test Spaces
    if [[ $(jq -r '.storage.spaces.enabled' "$config_file") == "true" ]]; then
        echo -e "\nTesting DigitalOcean Spaces:"
        local bucket=$(jq -r '.storage.spaces.bucket' "$config_file")
        local path=$(jq -r '.storage.spaces.path' "$config_file")
        local region=$(jq -r '.storage.spaces.region' "$config_file")
        
        if aws s3 cp "$test_file" "s3://${bucket}/${path}/test.txt" \
            --endpoint-url "https://${region}.digitaloceanspaces.com"; then
            echo "✅ Spaces upload test passed"
            aws s3 rm "s3://${bucket}/${path}/test.txt" \
                --endpoint-url "https://${region}.digitaloceanspaces.com"
            echo "✅ Spaces delete test passed"
        else
            echo "❌ Spaces storage test failed"
        fi
    fi
    
    # Cleanup
    rm -f "$test_file"
    
    echo -e "\nStorage tests completed."
}

# Usage check
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 domain"
    exit 1
fi

test_storage "$1"