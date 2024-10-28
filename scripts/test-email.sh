# scripts/test-email.sh
#!/bin/bash

set -euo pipefail

test_email() {
    local domain=$1
    local config_file="/var/www/${domain}/config/contact.json"
    local test_recipient=$(jq -r '.recipient_email' "$config_file")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "Testing email system for ${domain}"
    echo "================================="
    
    # Test standard mail
    echo "Testing standard mail delivery..."
    if echo "Test email from ${domain} at ${timestamp}" | mail -s "Test Email" "$test_recipient"; then
        echo "✅ Standard mail test sent"
    else
        echo "❌ Standard mail test failed"
    fi
    
    # Test PHP mail
    echo -e "\nTesting PHP mail function..."
    local php_test=$(php -r "
        \$result = mail('${test_recipient}', 
                       'PHP Test Email', 
                       'Test PHP mail function from ${domain} at ${timestamp}', 
                       'From: noreply@${domain}');
        echo \$result ? 'success' : 'failure';
    ")
    
    if [[ "$php_test" == "success" ]]; then
        echo "✅ PHP mail test sent"
    else
        echo "❌ PHP mail test failed"
    fi
    
    # Test mail configuration
    echo -e "\nMail configuration:"
    postconf | grep "^myhostname\|^mydomain\|^myorigin\|^relayhost"
    
    echo -e "\nMail queue:"
    mailq
    
    echo -e "\nMail logs:"
    tail -n 10 /var/log/mail.log
}

# Usage check
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 domain"
    exit 1
fi

test_email "$1"