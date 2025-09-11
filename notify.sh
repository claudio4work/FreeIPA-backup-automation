#!/bin/bash
#
# FreeIPA Backup Notification Script
# Handles email and webhook notifications for backup operations
#

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Default values
EMAIL_NOTIFICATIONS=false
EMAIL_TO=""
EMAIL_SUBJECT_PREFIX="[FreeIPA Backup]"
SMTP_SERVER=""
SMTP_PORT="587"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_USE_TLS=true
WEBHOOK_URL=""

# Source config file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Send email notification
send_email() {
    local subject="$1"
    local body="$2"
    local priority="$3"  # normal, high, low
    
    if [[ "$EMAIL_NOTIFICATIONS" != "true" ]] || [[ -z "$EMAIL_TO" ]] || [[ -z "$SMTP_SERVER" ]]; then
        return 0
    fi
    
    local full_subject="${EMAIL_SUBJECT_PREFIX} ${subject}"
    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Create email body with additional info
    local email_body="Date: ${timestamp}
Host: ${hostname}
Subject: ${subject}

${body}

---
This is an automated message from the FreeIPA Backup System.
"
    
    # Prepare email headers
    local headers=""
    case "$priority" in
        high)
            headers="-o message-header='X-Priority: 1' -o message-header='Priority: urgent'"
            ;;
        low)
            headers="-o message-header='X-Priority: 5' -o message-header='Priority: non-urgent'"
            ;;
        *)
            headers="-o message-header='X-Priority: 3' -o message-header='Priority: normal'"
            ;;
    esac
    
    # Send email using curl (more reliable than mail/sendmail)
    if command -v curl >/dev/null 2>&1; then
        local auth_option=""
        if [[ -n "$SMTP_USER" ]]; then
            auth_option="--user ${SMTP_USER}:${SMTP_PASSWORD}"
        fi
        
        local tls_option=""
        if [[ "$SMTP_USE_TLS" == "true" ]]; then
            tls_option="--ssl-reqd"
        fi
        
        echo "$email_body" | curl --silent --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
            $auth_option \
            $tls_option \
            --mail-from "$SMTP_USER" \
            --mail-rcpt "$EMAIL_TO" \
            --upload-file - \
            -H "Subject: $full_subject" \
            -H "From: $SMTP_USER" \
            -H "To: $EMAIL_TO"
    fi
}

# Send webhook notification
send_webhook() {
    local title="$1"
    local message="$2"
    local status="$3"  # success, error, warning, info
    
    if [[ -z "$WEBHOOK_URL" ]]; then
        return 0
    fi
    
    local hostname=$(hostname)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Determine color based on status
    local color=""
    local emoji=""
    case "$status" in
        success)
            color="good"
            emoji="✅"
            ;;
        error)
            color="danger"
            emoji="❌"
            ;;
        warning)
            color="warning"
            emoji="⚠️"
            ;;
        *)
            color=""
            emoji="ℹ️"
            ;;
    esac
    
    # Create JSON payload (generic format that works with most webhooks)
    local json_payload=$(cat <<EOF
{
    "text": "${emoji} ${title}",
    "attachments": [
        {
            "color": "${color}",
            "fields": [
                {
                    "title": "Host",
                    "value": "${hostname}",
                    "short": true
                },
                {
                    "title": "Time",
                    "value": "${timestamp}",
                    "short": true
                },
                {
                    "title": "Details",
                    "value": "${message}",
                    "short": false
                }
            ]
        }
    ]
}
EOF
    )
    
    # Send webhook
    if command -v curl >/dev/null 2>&1; then
        curl --silent --header "Content-Type: application/json" \
             --data "$json_payload" \
             --max-time 30 \
             "$WEBHOOK_URL" >/dev/null 2>&1
    fi
}

# Parse log file and send notifications
parse_and_notify() {
    local log_file="$1"
    local operation="$2"  # backup, cleanup
    
    if [[ ! -f "$log_file" ]]; then
        return 1
    fi
    
    # Get the last operation from log file
    local last_log_entry=$(tail -n 50 "$log_file" | grep -E "\[(INFO|ERROR|WARN)\]" | tail -n 1)
    
    if [[ -z "$last_log_entry" ]]; then
        return 1
    fi
    
    # Extract timestamp, level, and message
    local timestamp=$(echo "$last_log_entry" | grep -o '^\[.*\]' | head -n 1)
    local level=$(echo "$last_log_entry" | grep -o '\[(INFO|ERROR|WARN)\]' | head -n 1 | tr -d '[]')
    local message=$(echo "$last_log_entry" | sed 's/^\[.*\] \[.*\] \[.*\] //')
    
    # Determine if it's a completion message
    local is_completion=false
    if echo "$message" | grep -q -E "(completed successfully|Cleanup completed)"; then
        is_completion=true
    fi
    
    # Only notify on completion or errors
    if [[ "$is_completion" == "true" ]] || [[ "$level" == "ERROR" ]]; then
        local status="info"
        local subject=""
        local priority="normal"
        
        case "$level" in
            ERROR)
                status="error"
                subject="❌ ${operation^} Failed"
                priority="high"
                ;;
            WARN)
                status="warning"
                subject="⚠️ ${operation^} Warning"
                ;;
            *)
                if [[ "$is_completion" == "true" ]]; then
                    status="success"
                    subject="✅ ${operation^} Completed"
                    priority="low"
                else
                    subject="ℹ️ ${operation^} Update"
                fi
                ;;
        esac
        
        # Get additional context from recent log entries
        local context=$(tail -n 20 "$log_file" | grep -E "\[(INFO|ERROR|WARN)\]" | tail -n 5)
        
        # Send notifications
        send_email "$subject" "$context" "$priority"
        send_webhook "$subject" "$message" "$status"
    fi
}

# Monitor log file for changes and send notifications
monitor_log() {
    local log_file="$1"
    local operation="$2"
    
    if [[ ! -f "$log_file" ]]; then
        echo "Log file does not exist: $log_file"
        return 1
    fi
    
    # Use inotifywait if available, otherwise fallback to tail
    if command -v inotifywait >/dev/null 2>&1; then
        echo "Monitoring log file: $log_file"
        inotifywait -m -e modify "$log_file" | while read -r path action file; do
            parse_and_notify "$log_file" "$operation"
        done
    else
        echo "inotifywait not available, using tail method"
        tail -F "$log_file" | while read -r line; do
            if echo "$line" | grep -q -E "\[(ERROR|INFO|WARN)\]"; then
                parse_and_notify "$log_file" "$operation"
            fi
        done
    fi
}

# Test notifications
test_notifications() {
    echo "Testing notification system..."
    
    send_email "🧪 Test Notification" "This is a test message to verify email notifications are working correctly." "normal"
    send_webhook "🧪 Test Notification" "This is a test message to verify webhook notifications are working correctly." "info"
    
    echo "Test notifications sent (if configured)."
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

FreeIPA Backup Notification Script

COMMANDS:
    parse LOG_FILE OPERATION    Parse log file and send notifications
    monitor LOG_FILE OPERATION  Monitor log file for changes
    test                        Send test notifications
    
OPERATIONS:
    backup     For backup operations
    cleanup    For cleanup operations

EXAMPLES:
    $0 parse /var/log/freeipa-backup.log backup
    $0 monitor /var/log/freeipa-backup.log backup &
    $0 test

Configuration is read from: $CONFIG_FILE
EOF
}

# Main function
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        parse)
            if [[ $# -lt 2 ]]; then
                echo "Error: parse command requires LOG_FILE and OPERATION arguments"
                usage
                exit 1
            fi
            parse_and_notify "$1" "$2"
            ;;
        monitor)
            if [[ $# -lt 2 ]]; then
                echo "Error: monitor command requires LOG_FILE and OPERATION arguments"
                usage
                exit 1
            fi
            monitor_log "$1" "$2"
            ;;
        test)
            test_notifications
            ;;
        *)
            echo "Error: Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
