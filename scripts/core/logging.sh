# scripts/core/logging.sh
#!/bin/bash

LOG_DIR="/var/log/multisite-server"
LOG_FILE="${LOG_DIR}/setup.log"
DEBUG_LOG="${LOG_DIR}/debug.log"

setup_logging() {
    mkdir -p "${LOG_DIR}"
    chmod 750 "${LOG_DIR}"

    # Initialize main log file
    touch "${LOG_FILE}"
    chmod 640 "${LOG_FILE}"

    # Initialize debug log if debug mode is enabled
    if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
        touch "${DEBUG_LOG}"
        chmod 640 "${DEBUG_LOG}"
    fi

    # Redirect stdout and stderr to log file while maintaining console output
    exec 1> >(tee -a "${LOG_FILE}")
    exec 2> >(tee -a "${LOG_FILE}" >&2)
}

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "${level}" in
        "INFO")
            echo "[${timestamp}] [INFO] ${message}" | tee -a "${LOG_FILE}"
            ;;
        "WARNING")
            echo "[${timestamp}] [WARNING] ${message}" | tee -a "${LOG_FILE}"
            ;;
        "ERROR")
            echo "[${timestamp}] [ERROR] ${message}" | tee -a "${LOG_FILE}"
            ;;
        "DEBUG")
            if [[ "${DEBUG_MODE:-0}" == "1" ]]; then
                echo "[${timestamp}] [DEBUG] ${message}" | tee -a "${DEBUG_LOG}"
            fi
            ;;
    esac
}

rotate_logs() {
    local max_size=100M
    local max_files=10

    if [[ -f "${LOG_FILE}" ]] && [[ $(stat -f%z "${LOG_FILE}") -gt $(numfmt --from=iec ${max_size}) ]]; then
        for i in $(seq $((max_files-1)) -1 1); do
            [[ -f "${LOG_FILE}.$i" ]] && mv "${LOG_FILE}.$i" "${LOG_FILE}.$((i+1))"
        done
        mv "${LOG_FILE}" "${LOG_FILE}.1"
        touch "${LOG_FILE}"
        chmod 640 "${LOG_FILE}"
    fi
}