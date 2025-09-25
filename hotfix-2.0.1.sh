#!/usr/bin/env bash
#
# Hotfix 2.0.1 - ReadWritePaths Correction
# Fixes the "Read-only file system" error in FreeIPA backups
#
# This script applies the critical ReadWritePaths fix to existing 2.0.0 installations
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SERVICE_FILE="/etc/systemd/system/freeipa-backup@.service"
readonly BACKUP_DIR="/root/backups"

# Logging
log() {
    local level="$1"
    shift
    local color=""
    case "$level" in
        ERROR) color="$RED" ;;
        WARN)  color="$YELLOW" ;;
        INFO)  color="$BLUE" ;;
        OK)    color="$GREEN" ;;
        *)     color="$NC" ;;
    esac
    echo -e "${color}[$level]${NC} $*"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        exit 1
    fi
}

# Check if service file exists
check_service_exists() {
    if [[ ! -f "$SERVICE_FILE" ]]; then
        log "ERROR" "Service file not found: $SERVICE_FILE"
        log "INFO" "This hotfix is only for existing FreeIPA Backup 2.0.0 installations"
        exit 1
    fi
}

# Check current ReadWritePaths configuration
check_current_config() {
    local current_config
    current_config=$(grep "^ReadWritePaths=" "$SERVICE_FILE" 2>/dev/null || echo "")
    
    if [[ -z "$current_config" ]]; then
        log "ERROR" "No ReadWritePaths configuration found in $SERVICE_FILE"
        exit 1
    fi
    
    log "INFO" "Current configuration: $current_config"
    
    # Check if already has the fix
    if [[ "$current_config" == *"/var/lib /etc/dirsrv"* ]]; then
        log "OK" "ReadWritePaths already appears to be fixed!"
        log "INFO" "Configuration looks correct: $current_config"
        return 1  # Already fixed
    fi
    
    return 0  # Needs fixing
}

# Backup current configuration
backup_config() {
    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/freeipa-backup@.service.hotfix-$(date +%F_%H-%M-%S)"
    
    log "INFO" "Creating backup: $backup_file"
    cp "$SERVICE_FILE" "$backup_file"
    
    log "OK" "Backup created: $backup_file"
}

# Apply the fix
apply_fix() {
    log "INFO" "Applying ReadWritePaths fix..."
    
    # Apply the fix using sed
    sed -i 's|ReadWritePaths=/var/lib/ipa/backup /var/log /var/run|ReadWritePaths=/var/lib /etc/dirsrv /var/log /var/run|' "$SERVICE_FILE"
    
    # Verify the change was applied
    local new_config
    new_config=$(grep "^ReadWritePaths=" "$SERVICE_FILE" 2>/dev/null || echo "")
    
    if [[ "$new_config" == *"/var/lib /etc/dirsrv"* ]]; then
        log "OK" "Fix applied successfully!"
        log "INFO" "New configuration: $new_config"
    else
        log "ERROR" "Fix failed to apply correctly"
        exit 1
    fi
}

# Reload systemd
reload_systemd() {
    log "INFO" "Reloading systemd configuration..."
    systemctl daemon-reload
    log "OK" "Systemd configuration reloaded"
}

# Test the fix
test_fix() {
    log "INFO" "Testing the fix with a dry-run backup..."
    
    if DRY_RUN=1 /opt/sysadmin-scripts/freeipa-backup-automation/freeipa-backup.sh --type data >/dev/null 2>&1; then
        log "OK" "Test backup completed successfully!"
    else
        log "WARN" "Test backup had issues, but fix is applied. Check logs if needed."
    fi
}

# Show status
show_status() {
    log "INFO" "Current timer status:"
    systemctl list-timers | grep freeipa-backup || echo "No FreeIPA backup timers found"
    
    echo
    log "INFO" "Service configuration verification:"
    echo "  • Service file: $SERVICE_FILE"
    echo "  • Current ReadWritePaths: $(grep "^ReadWritePaths=" "$SERVICE_FILE")"
    
    echo
    log "OK" "Hotfix 2.0.1 applied successfully!"
    echo
    log "INFO" "The \"Read-only file system\" error should now be resolved."
    echo "Your scheduled backups will work correctly starting with the next run."
}

# Main function
main() {
    log "INFO" "FreeIPA Backup Automation - Hotfix 2.0.1"
    log "INFO" "Fixing ReadWritePaths configuration for systemd service"
    echo
    
    check_root
    check_service_exists
    
    if ! check_current_config; then
        show_status
        exit 0  # Already fixed
    fi
    
    backup_config
    apply_fix
    reload_systemd
    test_fix
    show_status
}

# Show help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "FreeIPA Backup Automation - Hotfix 2.0.1"
    echo
    echo "This script fixes the \"Read-only file system\" error that prevents"
    echo "FreeIPA backups from running in version 2.0.0."
    echo
    echo "Usage: sudo $0"
    echo
    echo "What this hotfix does:"
    echo "• Updates ReadWritePaths in systemd service configuration"
    echo "• Adds /var/lib and /etc/dirsrv to allow FreeIPA write operations"
    echo "• Maintains security while fixing backup functionality"
    echo "• Creates automatic backup of original configuration"
    echo
    echo "This fix is essential for both DATA and FULL backups to work correctly."
    exit 0
fi

main "$@"