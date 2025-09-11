#!/bin/bash
#
# FreeIPA Backup Script
# Performs automated backup of FreeIPA server with proper error handling
#

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Default values
BACKUP_DIR="/var/lib/ipa/backup"
LOG_FILE="/var/log/freeipa-backup.log"
LOCK_FILE="/var/run/freeipa-backup.lock"

# Source config file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "ERROR" "$1"
    cleanup
    exit 1
}

# Cleanup function
cleanup() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
    fi
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root"
    fi
}

# Check if another backup is running
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            error_exit "Another backup process is already running (PID: $pid)"
        else
            log "WARN" "Stale lock file found, removing it"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Check if FreeIPA is installed and configured
check_freeipa() {
    if ! command -v ipactl >/dev/null 2>&1; then
        error_exit "ipactl command not found. Is FreeIPA installed?"
    fi
    
    if ! command -v ipa-backup >/dev/null 2>&1; then
        error_exit "ipa-backup command not found. Is FreeIPA installed?"
    fi
}

# Check FreeIPA service status
check_ipa_status() {
    if ! ipactl status >/dev/null 2>&1; then
        log "WARN" "FreeIPA services are not running"
        return 1
    fi
    return 0
}

# Stop FreeIPA services
stop_ipa() {
    log "INFO" "Stopping FreeIPA services..."
    if ! ipactl stop; then
        error_exit "Failed to stop FreeIPA services"
    fi
    log "INFO" "FreeIPA services stopped successfully"
}

# Start FreeIPA services
start_ipa() {
    log "INFO" "Starting FreeIPA services..."
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if ipactl start; then
            log "INFO" "FreeIPA services started successfully"
            return 0
        else
            log "WARN" "Failed to start FreeIPA services (attempt $attempt/$max_attempts)"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep 10
            fi
            ((attempt++))
        fi
    done
    
    error_exit "Failed to start FreeIPA services after $max_attempts attempts"
}

# Perform backup
perform_backup() {
    local backup_name="ipa-backup-$(date +%Y%m%d-%H%M%S)"
    log "INFO" "Starting backup: $backup_name"
    
    # Ensure backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "INFO" "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory"
    fi
    
    # Perform the backup
    if ipa-backup -v --data --online; then
        log "INFO" "Backup completed successfully"
        
        # Find the most recent backup directory
        local latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ipa-full-*" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
        
        if [[ -n "$latest_backup" ]]; then
            log "INFO" "Latest backup location: $latest_backup"
            
            # Create a symlink to the latest backup
            ln -sfn "$latest_backup" "$BACKUP_DIR/latest"
            
            # Get backup size
            local backup_size=$(du -sh "$latest_backup" 2>/dev/null | cut -f1)
            log "INFO" "Backup size: ${backup_size:-unknown}"
        fi
    else
        error_exit "Backup failed"
    fi
}

# Main function
main() {
    log "INFO" "Starting FreeIPA backup process"
    
    # Pre-flight checks
    check_root
    check_lock
    check_freeipa
    
    # Store initial FreeIPA status
    local ipa_was_running=false
    if check_ipa_status; then
        ipa_was_running=true
    fi
    
    # Trap to ensure cleanup and service restart on exit
    trap 'cleanup; if $ipa_was_running && ! check_ipa_status; then log "WARN" "Attempting to restart FreeIPA services..."; start_ipa; fi' EXIT
    
    # Perform backup process
    if $ipa_was_running; then
        stop_ipa
    fi
    
    perform_backup
    
    if $ipa_was_running; then
        start_ipa
    fi
    
    log "INFO" "FreeIPA backup process completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
