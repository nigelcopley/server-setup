# scripts/monitoring/metrics.sh
#!/bin/bash

collect_system_metrics() {
    local domain=$1
    local metrics_file="/var/www/${domain}/metrics/system.prom"

    # Collect system metrics
    {
        echo "# HELP system_memory_usage_bytes Memory usage in bytes"
        echo "# TYPE system_memory_usage_bytes gauge"
        echo "system_memory_usage_bytes{domain=\"${domain}\"} $(free -b | awk '/Mem:/ {print $3}')"

        echo "# HELP system_cpu_usage_percent CPU usage percentage"
        echo "# TYPE system_cpu_usage_percent gauge"
        echo "system_cpu_usage_percent{domain=\"${domain}\"} $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"

        echo "# HELP system_disk_usage_percent Disk usage percentage"
        echo "# TYPE system_disk_usage_percent gauge"
        echo "system_disk_usage_percent{domain=\"${domain}\"} $(df -h /var/www/${domain} | awk 'NR==2 {print $5}' | tr -d '%')"
    } > "$metrics_file"
}

collect_nginx_metrics() {
    local domain=$1
    local metrics_file="/var/www/${domain}/metrics/nginx.prom"

    # Parse NGINX access log for metrics
    {
        echo "# HELP nginx_requests_total Total number of HTTP requests"
        echo "# TYPE nginx_requests_total counter"
        echo "nginx_requests_total{domain=\"${domain}\"} $(wc -l < "/var/www/${domain}/logs/access.log")"

        echo "# HELP nginx_error_count_total Total number of HTTP errors"
        echo "# TYPE nginx_error_count_total counter"
        echo "nginx_error_count_total{domain=\"${domain}\"} $(grep -c " [45][0-9][0-9] " "/var/www/${domain}/logs/access.log")"
    } > "$metrics_file"
}
