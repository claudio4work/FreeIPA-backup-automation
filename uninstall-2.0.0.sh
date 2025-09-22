#!/usr/bin/env bash
#
# Desinstalação Completa FreeIPA Backup Automation 2.0.0
# Remove todos os componentes do sistema de backup
#

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly INSTALL_DIR_V2="/opt/sysadmin-scripts/freeipa-backup-automation"
readonly INSTALL_DIR_V1="/usr/local/bin"
readonly CONFIG_DIR="/etc/freeipa-backup-automation"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly SHARE_DIR="/usr/local/share/freeipa-backup-automation"
readonly BACKUP_DIR="/var/lib/ipa/backup"

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

# Backup data before removal
backup_before_removal() {
    local backup_dir="/root/backups/freeipa-backup-uninstall-$(date +%F_%H-%M-%S)"
    
    log "INFO" "Creating backup before uninstall in $backup_dir"
    mkdir -p "$backup_dir"
    
    # Backup configuration
    [[ -d "$CONFIG_DIR" ]] && cp -r "$CONFIG_DIR" "$backup_dir/"
    
    # Backup any custom scripts
    [[ -d "$INSTALL_DIR_V2" ]] && cp -r "$INSTALL_DIR_V2" "$backup_dir/"
    [[ -f "$INSTALL_DIR_V1/freeipa-backup.sh" ]] && cp "$INSTALL_DIR_V1/freeipa-backup.sh" "$backup_dir/"
    [[ -f "$INSTALL_DIR_V1/backup-cleanup.sh" ]] && cp "$INSTALL_DIR_V1/backup-cleanup.sh" "$backup_dir/"
    [[ -f "$INSTALL_DIR_V1/notify.sh" ]] && cp "$INSTALL_DIR_V1/notify.sh" "$backup_dir/"
    
    # Backup systemd files
    mkdir -p "$backup_dir/systemd"
    cp "$SYSTEMD_DIR"/freeipa-backup* "$backup_dir/systemd/" 2>/dev/null || true
    
    # Backup logs (last 100 lines)
    [[ -f "/var/log/freeipa-backup.log" ]] && tail -n 100 "/var/log/freeipa-backup.log" > "$backup_dir/last-100-log-lines.txt"
    
    log "OK" "Backup completed in $backup_dir"
    echo "$backup_dir" > /tmp/freeipa-backup-uninstall-backup-path
}

# Stop and disable all services
stop_services() {
    log "INFO" "Stopping and disabling FreeIPA backup services..."
    
    # Version 2.0.0 services
    systemctl stop freeipa-backup-data.timer 2>/dev/null || true
    systemctl stop freeipa-backup-full.timer 2>/dev/null || true  
    systemctl stop freeipa-backup-cleanup.timer 2>/dev/null || true
    systemctl disable freeipa-backup-data.timer 2>/dev/null || true
    systemctl disable freeipa-backup-full.timer 2>/dev/null || true
    systemctl disable freeipa-backup-cleanup.timer 2>/dev/null || true
    systemctl disable freeipa-backup@data.service 2>/dev/null || true
    systemctl disable freeipa-backup@full.service 2>/dev/null || true
    systemctl disable freeipa-backup-cleanup.service 2>/dev/null || true
    
    # Version 1.0.0 services (legacy)
    systemctl stop freeipa-backup.timer 2>/dev/null || true
    systemctl stop freeipa-backup-cleanup.timer 2>/dev/null || true
    systemctl disable freeipa-backup.timer 2>/dev/null || true
    systemctl disable freeipa-backup.service 2>/dev/null || true
    systemctl disable freeipa-backup-cleanup.timer 2>/dev/null || true
    systemctl disable freeipa-backup-cleanup.service 2>/dev/null || true
    
    log "OK" "Services stopped and disabled"
}

# Remove systemd files
remove_systemd_files() {
    log "INFO" "Removing systemd files..."
    
    # Version 2.0.0 systemd files
    rm -f "$SYSTEMD_DIR/freeipa-backup@.service"
    rm -f "$SYSTEMD_DIR/freeipa-backup-data.timer"
    rm -f "$SYSTEMD_DIR/freeipa-backup-full.timer"
    rm -f "$SYSTEMD_DIR/freeipa-backup-cleanup.service"
    rm -f "$SYSTEMD_DIR/freeipa-backup-cleanup.timer"
    
    # Version 1.0.0 systemd files (legacy)  
    rm -f "$SYSTEMD_DIR/freeipa-backup.service"
    rm -f "$SYSTEMD_DIR/freeipa-backup.timer"
    rm -f "$SYSTEMD_DIR/freeipa-backup-cleanup.service"
    rm -f "$SYSTEMD_DIR/freeipa-backup-cleanup.timer"
    
    # Reload systemd
    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    
    log "OK" "Systemd files removed"
}

# Remove scripts
remove_scripts() {
    log "INFO" "Removing scripts..."
    
    # Version 2.0.0 scripts
    rm -rf "$INSTALL_DIR_V2"
    
    # Version 1.0.0 scripts (legacy)
    rm -f "$INSTALL_DIR_V1/freeipa-backup.sh"
    rm -f "$INSTALL_DIR_V1/backup-cleanup.sh"
    rm -f "$INSTALL_DIR_V1/notify.sh"
    
    # Documentation
    rm -rf "$SHARE_DIR"
    
    log "OK" "Scripts removed"
}

# Remove logrotate configuration
remove_logrotate() {
    log "INFO" "Removing logrotate configuration..."
    
    rm -f /etc/logrotate.d/freeipa-backup
    
    log "OK" "Logrotate configuration removed"
}

# Show what will be preserved
show_preserved() {
    log "INFO" "The following will be PRESERVED:"
    echo "  ✅ Backups in: $BACKUP_DIR"
    [[ -d "$CONFIG_DIR" ]] && echo "  ✅ Configuration in: $CONFIG_DIR"
    [[ -f "/var/log/freeipa-backup.log" ]] && echo "  ✅ Logs in: /var/log/freeipa-backup.log*"
    
    local backup_path
    backup_path=$(cat /tmp/freeipa-backup-uninstall-backup-path 2>/dev/null || echo "")
    [[ -n "$backup_path" ]] && echo "  ✅ Pre-uninstall backup in: $backup_path"
    
    echo ""
    log "WARN" "To completely remove everything including backups and logs:"
    echo "  sudo rm -rf $BACKUP_DIR"
    echo "  sudo rm -rf $CONFIG_DIR" 
    echo "  sudo rm -f /var/log/freeipa-backup.log*"
    [[ -n "$backup_path" ]] && echo "  sudo rm -rf $backup_path"
}

# Show summary
show_summary() {
    echo ""
    log "OK" "FreeIPA Backup Automation uninstallation completed!"
    echo ""
    log "INFO" "Removed components:"
    echo "  ❌ All systemd services and timers"
    echo "  ❌ All backup scripts (v1.0.0 and v2.0.0)"
    echo "  ❌ Logrotate configuration"
    echo "  ❌ Documentation"
    echo ""
    show_preserved
    echo ""
    log "INFO" "System cleanup recommendations:"
    echo "  • Review and remove any custom cron jobs"
    echo "  • Check for any remaining FreeIPA backup processes: ps aux | grep freeipa-backup"
    echo "  • Verify no remaining systemd units: systemctl list-units | grep freeipa"
    echo ""
}

# Force remove everything including data
force_remove_all() {
    log "WARN" "FORCE MODE: This will remove EVERYTHING including backups and configuration!"
    echo "This includes:"
    echo "  • All backups in $BACKUP_DIR"
    echo "  • All configuration in $CONFIG_DIR"
    echo "  • All logs in /var/log/freeipa-backup.log*"
    echo ""
    read -p "Are you absolutely sure? Type 'DELETE EVERYTHING' to proceed: " confirmation
    
    if [[ "$confirmation" == "DELETE EVERYTHING" ]]; then
        log "WARN" "Removing all data..."
        rm -rf "$BACKUP_DIR"
        rm -rf "$CONFIG_DIR"
        rm -f /var/log/freeipa-backup.log*
        rm -rf /root/backups/freeipa-backup-*
        log "OK" "All data removed"
    else
        log "INFO" "Force removal cancelled"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

FreeIPA Backup Automation Uninstallation Script

OPTIONS:
    --force         Remove everything including backups, config and logs
    --dry-run       Show what would be removed without actually removing
    --help          Show this help message

EXAMPLES:
    $0                    # Standard uninstall (preserves data)
    $0 --dry-run          # Show what would be removed
    $0 --force            # Remove everything including backups

WHAT GETS REMOVED (standard):
    • All systemd services and timers
    • All backup scripts (both v1.0.0 and v2.0.0)
    • Logrotate configuration
    • Documentation

WHAT GETS PRESERVED (standard):
    • Existing backups in $BACKUP_DIR
    • Configuration in $CONFIG_DIR
    • Log files in /var/log/freeipa-backup.log*

EOF
}

# Dry run mode
dry_run() {
    log "INFO" "DRY RUN MODE - Showing what would be removed:"
    echo ""
    
    log "INFO" "Services that would be stopped and disabled:"
    systemctl list-units | grep freeipa || echo "  (none found)"
    echo ""
    
    log "INFO" "Systemd files that would be removed:"
    find "$SYSTEMD_DIR" -name "freeipa-backup*" 2>/dev/null || echo "  (none found)"
    echo ""
    
    log "INFO" "Scripts that would be removed:"
    [[ -d "$INSTALL_DIR_V2" ]] && echo "  $INSTALL_DIR_V2/"
    [[ -f "$INSTALL_DIR_V1/freeipa-backup.sh" ]] && echo "  $INSTALL_DIR_V1/freeipa-backup.sh"
    [[ -f "$INSTALL_DIR_V1/backup-cleanup.sh" ]] && echo "  $INSTALL_DIR_V1/backup-cleanup.sh"
    [[ -f "$INSTALL_DIR_V1/notify.sh" ]] && echo "  $INSTALL_DIR_V1/notify.sh"
    [[ -d "$SHARE_DIR" ]] && echo "  $SHARE_DIR/"
    echo ""
    
    log "INFO" "Other files that would be removed:"
    [[ -f "/etc/logrotate.d/freeipa-backup" ]] && echo "  /etc/logrotate.d/freeipa-backup"
    echo ""
    
    show_preserved
}

# Main function
main() {
    local dry_run_mode=false
    local force_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force_mode=true
                shift
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Execute based on mode
    if [[ "$dry_run_mode" == "true" ]]; then
        dry_run
    else
        check_root
        
        if [[ "$force_mode" == "true" ]]; then
            backup_before_removal
            stop_services
            remove_systemd_files
            remove_scripts
            remove_logrotate
            force_remove_all
            show_summary
        else
            backup_before_removal
            stop_services
            remove_systemd_files
            remove_scripts
            remove_logrotate
            show_summary
        fi
    fi
}

# Run main function
main "$@"