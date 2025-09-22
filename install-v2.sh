#!/usr/bin/env bash
#
# Instalação/Atualização FreeIPA Backup v2.0
# Script para atualizar do sistema v1.0 para v2.0
#

set -euo pipefail
umask 077

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="/opt/sysadmin-scripts/freeipa-backup-automation"
readonly SYSTEMD_DIR="/etc/systemd/system"

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

# Backup current installation
backup_current() {
    local backup_dir="/root/backups/freeipa-backup-v2-upgrade-$(date +%F_%H-%M-%S)"
    
    log "INFO" "Creating backup in $backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup current files
    [[ -f "$INSTALL_DIR/freeipa-backup.sh" ]] && cp -a "$INSTALL_DIR/freeipa-backup.sh" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup.service" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup.service" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup.timer" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup.timer" "$backup_dir/"
    
    log "OK" "Backup completed in $backup_dir"
    echo "$backup_dir" > /tmp/freeipa-backup-v2-backup-path
}

# Install new files
install_files() {
    log "INFO" "Installing new files..."
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Install new script
    cp "$SCRIPT_DIR/freeipa-backup.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/freeipa-backup.sh"
    
    # Install new systemd files
    cp "$SCRIPT_DIR/systemd-v2/freeipa-backup@.service" "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd-v2/freeipa-backup-data.timer" "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd-v2/freeipa-backup-full.timer" "$SYSTEMD_DIR/"
    
    log "OK" "Files installed successfully"
}

# Update systemd and timers
update_systemd() {
    log "INFO" "Updating systemd configuration..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Stop and disable old timer
    systemctl disable --now freeipa-backup.timer 2>/dev/null || true
    
    # Enable and start new timers
    systemctl enable --now freeipa-backup-data.timer
    systemctl enable --now freeipa-backup-full.timer
    
    log "OK" "Systemd configuration updated"
}

# Show status
show_status() {
    log "INFO" "Current timer status:"
    systemctl list-timers | grep freeipa-backup || echo "No FreeIPA backup timers found"
    echo
    
    log "INFO" "Testing new script..."
    DRY_RUN=1 "$INSTALL_DIR/freeipa-backup.sh" --type auto
    
    echo
    log "OK" "Installation completed successfully!"
    echo
    log "INFO" "Next steps:"
    echo "  1. Review logs: journalctl -u freeipa-backup-data.service"
    echo "  2. Test manually: sudo $INSTALL_DIR/freeipa-backup.sh --type data" 
    echo "  3. Monitor timers: systemctl list-timers | grep freeipa-backup"
    echo
}

# Rollback function
rollback() {
    local backup_path
    backup_path=$(cat /tmp/freeipa-backup-v2-backup-path 2>/dev/null || echo "")
    
    if [[ -z "$backup_path" ]]; then
        log "ERROR" "No backup path found for rollback"
        return 1
    fi
    
    log "WARN" "Rolling back to previous version..."
    
    # Restore files
    [[ -f "$backup_path/freeipa-backup.sh" ]] && cp "$backup_path/freeipa-backup.sh" "$INSTALL_DIR/"
    [[ -f "$backup_path/freeipa-backup.service" ]] && cp "$backup_path/freeipa-backup.service" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup.timer" ]] && cp "$backup_path/freeipa-backup.timer" "$SYSTEMD_DIR/"
    
    # Disable new timers
    systemctl disable --now freeipa-backup-data.timer freeipa-backup-full.timer 2>/dev/null || true
    
    # Enable old timer
    systemctl daemon-reload
    systemctl enable --now freeipa-backup.timer 2>/dev/null || true
    
    log "OK" "Rollback completed"
}

# Main function
main() {
    case "${1:-install}" in
        install|update)
            check_root
            backup_current
            install_files
            update_systemd
            show_status
            ;;
        rollback)
            check_root
            rollback
            ;;
        test)
            DRY_RUN=1 "$INSTALL_DIR/freeipa-backup.sh" --type auto
            ;;
        *)
            echo "Usage: $0 [install|rollback|test]"
            echo "  install  - Install/update to v2.0 (default)"
            echo "  rollback - Rollback to previous version"
            echo "  test     - Test the installed script"
            exit 1
            ;;
    esac
}

main "$@"