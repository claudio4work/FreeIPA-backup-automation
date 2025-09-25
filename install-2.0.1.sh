#!/usr/bin/env bash
#
# Instalação/Atualização FreeIPA Backup 2.0.1
# Script para instalação direta da versão 2.0.1 (com correção ReadWritePaths)
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
    local backup_dir="/root/backups/freeipa-backup-2.0.1-upgrade-$(date +%F_%H-%M-%S)"
    
    log "INFO" "Creating backup in $backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup current files (any existing version)
    [[ -f "$INSTALL_DIR/freeipa-backup.sh" ]] && cp -a "$INSTALL_DIR/freeipa-backup.sh" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup.service" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup.service" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup.timer" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup.timer" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup@.service" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup@.service" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup-data.timer" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup-data.timer" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup-full.timer" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup-full.timer" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup-cleanup.service" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup-cleanup.service" "$backup_dir/"
    [[ -f "$SYSTEMD_DIR/freeipa-backup-cleanup.timer" ]] && cp -a "$SYSTEMD_DIR/freeipa-backup-cleanup.timer" "$backup_dir/"
    
    log "OK" "Backup completed in $backup_dir"
    echo "$backup_dir" > /tmp/freeipa-backup-2.0.1-backup-path
}

# Install new files
install_files() {
    log "INFO" "Installing FreeIPA Backup 2.0.1 files..."
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Install new scripts
    cp "$SCRIPT_DIR/freeipa-backup.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/backup-cleanup.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/notify.sh" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/freeipa-backup.sh"
    chmod +x "$INSTALL_DIR/backup-cleanup.sh"
    chmod +x "$INSTALL_DIR/notify.sh"
    
    # Install documentation
    [[ -f "$SCRIPT_DIR/README.md" ]] && cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/"
    [[ -f "$SCRIPT_DIR/CHANGELOG.md" ]] && cp "$SCRIPT_DIR/CHANGELOG.md" "$INSTALL_DIR/"
    
    # Install systemd files (v2.0.1 with ReadWritePaths fix)
    cp "$SCRIPT_DIR/systemd/freeipa-backup@.service" "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd/freeipa-backup-data.timer" "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd/freeipa-backup-full.timer" "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd/freeipa-backup-cleanup.service" "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd/freeipa-backup-cleanup.timer" "$SYSTEMD_DIR/"
    
    log "OK" "FreeIPA Backup 2.0.1 files installed successfully"
}

# Update systemd and timers
update_systemd() {
    log "INFO" "Updating systemd configuration..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Stop and disable any old timers/services (from any version)
    systemctl disable --now freeipa-backup.timer 2>/dev/null || true
    systemctl disable --now freeipa-backup.service 2>/dev/null || true
    systemctl disable --now freeipa-backup-data.timer 2>/dev/null || true
    systemctl disable --now freeipa-backup-full.timer 2>/dev/null || true
    systemctl disable --now freeipa-backup-cleanup.timer 2>/dev/null || true
    
    # Enable and start new timers (v2.0.1)
    systemctl enable --now freeipa-backup-data.timer
    systemctl enable --now freeipa-backup-full.timer
    systemctl enable --now freeipa-backup-cleanup.timer
    
    log "OK" "Systemd configuration updated for v2.0.1"
}

# Show status
show_status() {
    log "INFO" "Current timer status:"
    systemctl list-timers | grep freeipa-backup || echo "No FreeIPA backup timers found"
    echo
    
    log "INFO" "Testing new script..."
    DRY_RUN=1 "$INSTALL_DIR/freeipa-backup.sh" --type auto
    
    echo
    log "OK" "FreeIPA Backup 2.0.1 installation completed successfully!"
    echo
    log "INFO" "🎯 What's new in v2.0.1:"
    echo "  • ✅ CRITICAL FIX: ReadWritePaths systemd issue resolved"
    echo "  • ✅ Simplified systemd folder structure"
    echo "  • ✅ Enhanced compatibility with systemd security features"
    echo
    log "INFO" "Installation paths:"
    echo "  • Scripts: $INSTALL_DIR/"
    echo "  • Documentation: $INSTALL_DIR/README.md"
    echo "  • Changelog: $INSTALL_DIR/CHANGELOG.md"
    echo "  • Configuration: /etc/freeipa-backup-automation/config.conf"
    echo
    log "INFO" "Next steps:"
    echo "  1. Review logs: journalctl -u freeipa-backup-data.service"
    echo "  2. Test manually: sudo $INSTALL_DIR/freeipa-backup.sh --type data" 
    echo "  3. Monitor timers: systemctl list-timers | grep freeipa-backup"
    echo "  4. View documentation: less $INSTALL_DIR/README.md"
    echo
}

# Rollback function
rollback() {
    local backup_path
    backup_path=$(cat /tmp/freeipa-backup-2.0.1-backup-path 2>/dev/null || echo "")
    
    if [[ -z "$backup_path" ]]; then
        log "ERROR" "No backup path found for rollback"
        return 1
    fi
    
    log "WARN" "Rolling back from v2.0.1..."
    
    # Restore files
    [[ -f "$backup_path/freeipa-backup.sh" ]] && cp "$backup_path/freeipa-backup.sh" "$INSTALL_DIR/"
    [[ -f "$backup_path/freeipa-backup.service" ]] && cp "$backup_path/freeipa-backup.service" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup.timer" ]] && cp "$backup_path/freeipa-backup.timer" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup@.service" ]] && cp "$backup_path/freeipa-backup@.service" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup-data.timer" ]] && cp "$backup_path/freeipa-backup-data.timer" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup-full.timer" ]] && cp "$backup_path/freeipa-backup-full.timer" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup-cleanup.service" ]] && cp "$backup_path/freeipa-backup-cleanup.service" "$SYSTEMD_DIR/"
    [[ -f "$backup_path/freeipa-backup-cleanup.timer" ]] && cp "$backup_path/freeipa-backup-cleanup.timer" "$SYSTEMD_DIR/"
    
    # Disable v2.0.1 timers
    systemctl disable --now freeipa-backup-data.timer freeipa-backup-full.timer freeipa-backup-cleanup.timer 2>/dev/null || true
    
    # Try to enable previous version timers
    systemctl daemon-reload
    systemctl enable --now freeipa-backup.timer 2>/dev/null || true
    systemctl enable --now freeipa-backup-data.timer 2>/dev/null || true
    systemctl enable --now freeipa-backup-full.timer 2>/dev/null || true
    systemctl enable --now freeipa-backup-cleanup.timer 2>/dev/null || true
    
    log "OK" "Rollback completed"
}

# Main function
main() {
    case "${1:-install}" in
        install|update|upgrade)
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
            echo "Usage: $0 [install|upgrade|rollback|test]"
            echo "  install  - Install/update to 2.0.1 (default)"
            echo "  upgrade  - Same as install (upgrade from any version → 2.0.1)"
            echo "  rollback - Rollback to previous version"
            echo "  test     - Test the installed script"
            echo
            echo "🎯 FreeIPA Backup Automation v2.0.1 Features:"
            echo "  • ✅ CRITICAL FIX: Systemd ReadWritePaths compatibility"
            echo "  • ✅ Enhanced security with systemd sandboxing"
            echo "  • ✅ Separate data and full backup scheduling"
            echo "  • ✅ Automatic cleanup with configurable retention"
            echo "  • ✅ Comprehensive logging and notifications"
            echo
            echo "Examples:"
            echo "  sudo $0              # Fresh install or upgrade to v2.0.1"
            echo "  sudo $0 upgrade      # Upgrade from any version to v2.0.1"
            echo "  sudo $0 rollback     # Emergency rollback"
            echo "  sudo $0 test         # Test current installation"
            exit 1
            ;;
    esac
}

main "$@"