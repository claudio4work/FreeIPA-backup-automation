#!/bin/bash
#
# FreeIPA Backup Automation Installation Script
# Installs and configures the backup system including systemd services
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation paths
INSTALL_PREFIX="/usr/local"
BIN_DIR="${INSTALL_PREFIX}/bin"
SHARE_DIR="${INSTALL_PREFIX}/share/freeipa-backup-automation"
CONFIG_DIR="/etc/freeipa-backup-automation"
SYSTEMD_DIR="/etc/systemd/system"
LOG_DIR="/var/log"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check if FreeIPA is installed
check_freeipa() {
    if ! command -v ipactl >/dev/null 2>&1; then
        error "ipactl command not found. Is FreeIPA installed?"
        exit 1
    fi
    
    if ! command -v ipa-backup >/dev/null 2>&1; then
        error "ipa-backup command not found. Is FreeIPA installed?"
        exit 1
    fi
    
    success "FreeIPA installation detected"
}

# Create directories
create_directories() {
    log "Creating installation directories..."
    
    mkdir -p "$BIN_DIR"
    mkdir -p "$SHARE_DIR"
    mkdir -p "$CONFIG_DIR"
    
    # Create backup directory if it doesn't exist
    if [[ ! -d "/var/lib/ipa/backup" ]]; then
        log "Creating backup directory..."
        mkdir -p "/var/lib/ipa/backup"
        chown root:root "/var/lib/ipa/backup"
        chmod 755 "/var/lib/ipa/backup"
    fi
    
    success "Directories created"
}

# Install scripts
install_scripts() {
    log "Installing scripts..."
    
    # Copy main scripts
    cp "$SCRIPT_DIR/freeipa-backup.sh" "$BIN_DIR/"
    cp "$SCRIPT_DIR/backup-cleanup.sh" "$BIN_DIR/"
    cp "$SCRIPT_DIR/notify.sh" "$BIN_DIR/"
    
    # Make scripts executable
    chmod +x "$BIN_DIR/freeipa-backup.sh"
    chmod +x "$BIN_DIR/backup-cleanup.sh"
    chmod +x "$BIN_DIR/notify.sh"
    
    # Copy documentation
    if [[ -f "$SCRIPT_DIR/README.md" ]]; then
        cp "$SCRIPT_DIR/README.md" "$SHARE_DIR/"
    fi
    
    success "Scripts installed"
}

# Install configuration
install_config() {
    log "Installing configuration..."
    
    # Copy configuration file if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/config.conf" ]]; then
        cp "$SCRIPT_DIR/config.conf" "$CONFIG_DIR/"
        chmod 644 "$CONFIG_DIR/config.conf"
        log "Configuration file copied to $CONFIG_DIR/config.conf"
    else
        warn "Configuration file already exists, skipping: $CONFIG_DIR/config.conf"
    fi
    
    # Update scripts to use system config path
    sed -i "s|CONFIG_FILE=\"\${SCRIPT_DIR}/config.conf\"|CONFIG_FILE=\"$CONFIG_DIR/config.conf\"|g" \
        "$BIN_DIR/freeipa-backup.sh" \
        "$BIN_DIR/backup-cleanup.sh" \
        "$BIN_DIR/notify.sh"
    
    success "Configuration installed"
}

# Install systemd services
install_systemd() {
    log "Installing systemd services..."
    
    # Copy service files
    cp "$SCRIPT_DIR/systemd/"*.service "$SYSTEMD_DIR/"
    cp "$SCRIPT_DIR/systemd/"*.timer "$SYSTEMD_DIR/"
    
    # Set permissions
    chmod 644 "$SYSTEMD_DIR"/freeipa-backup*
    
    # Reload systemd
    systemctl daemon-reload
    
    success "Systemd services installed"
}

# Configure log rotation
configure_logrotate() {
    log "Configuring log rotation..."
    
    cat > /etc/logrotate.d/freeipa-backup << 'EOF'
/var/log/freeipa-backup.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
    postrotate
        # Send signal to any running backup processes to reopen log file
        systemctl kill --signal=USR1 freeipa-backup.service 2>/dev/null || true
    endscript
}
EOF
    
    success "Log rotation configured"
}

# Enable and start services
enable_services() {
    local enable_timers="$1"
    
    log "Enabling systemd services..."
    
    # Enable services
    systemctl enable freeipa-backup.service
    systemctl enable freeipa-backup-cleanup.service
    
    if [[ "$enable_timers" == "true" ]]; then
        # Enable and start timers
        systemctl enable freeipa-backup.timer
        systemctl enable freeipa-backup-cleanup.timer
        systemctl start freeipa-backup.timer
        systemctl start freeipa-backup-cleanup.timer
        
        success "Services and timers enabled and started"
        
        # Show timer status
        log "Timer status:"
        systemctl list-timers freeipa-backup*
    else
        success "Services enabled (timers not started)"
        warn "To start automated backups, run: systemctl start freeipa-backup.timer"
        warn "To start automated cleanup, run: systemctl start freeipa-backup-cleanup.timer"
    fi
}

# Run test backup
test_backup() {
    log "Running test backup..."
    
    if systemctl start freeipa-backup.service; then
        success "Test backup completed successfully"
        
        # Show backup status
        log "Backup status:"
        "$BIN_DIR/backup-cleanup.sh" --status || true
    else
        error "Test backup failed"
        warn "Check logs with: journalctl -u freeipa-backup.service"
        return 1
    fi
}

# Show installation summary
show_summary() {
    echo ""
    success "FreeIPA Backup Automation installation completed!"
    echo ""
    log "Installation paths:"
    echo "  Scripts:       $BIN_DIR"
    echo "  Configuration: $CONFIG_DIR"
    echo "  Documentation: $SHARE_DIR"
    echo "  Systemd units: $SYSTEMD_DIR"
    echo ""
    log "Configuration file: $CONFIG_DIR/config.conf"
    log "Log file:          /var/log/freeipa-backup.log"
    echo ""
    log "Commands:"
    echo "  Manual backup:    systemctl start freeipa-backup.service"
    echo "  Manual cleanup:   systemctl start freeipa-backup-cleanup.service"
    echo "  Check status:     $BIN_DIR/backup-cleanup.sh --status"
    echo "  Test notifications: $BIN_DIR/notify.sh test"
    echo ""
    log "Timer management:"
    echo "  Start timers:     systemctl start freeipa-backup.timer freeipa-backup-cleanup.timer"
    echo "  Stop timers:      systemctl stop freeipa-backup.timer freeipa-backup-cleanup.timer"
    echo "  Timer status:     systemctl list-timers freeipa-backup*"
    echo ""
}

# Uninstall function
uninstall() {
    log "Uninstalling FreeIPA Backup Automation..."
    
    # Stop and disable timers
    systemctl stop freeipa-backup.timer freeipa-backup-cleanup.timer 2>/dev/null || true
    systemctl disable freeipa-backup.timer freeipa-backup-cleanup.timer 2>/dev/null || true
    
    # Disable services
    systemctl disable freeipa-backup.service freeipa-backup-cleanup.service 2>/dev/null || true
    
    # Remove files
    rm -f "$BIN_DIR/freeipa-backup.sh"
    rm -f "$BIN_DIR/backup-cleanup.sh" 
    rm -f "$BIN_DIR/notify.sh"
    rm -f "$SYSTEMD_DIR"/freeipa-backup*
    rm -f /etc/logrotate.d/freeipa-backup
    rm -rf "$SHARE_DIR"
    
    # Reload systemd
    systemctl daemon-reload
    
    warn "Configuration preserved in: $CONFIG_DIR"
    warn "Backups preserved in: /var/lib/ipa/backup"
    warn "Logs preserved in: /var/log/freeipa-backup.log*"
    
    success "Uninstallation completed"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

FreeIPA Backup Automation Installation Script

COMMANDS:
    install     Install the backup system (default)
    uninstall   Remove the backup system
    
OPTIONS:
    --no-timers     Install services but don't start timers
    --no-test       Skip test backup during installation
    --help          Show this help message

EXAMPLES:
    $0                    # Full installation with timers
    $0 --no-timers        # Install but don't start automatic scheduling
    $0 --no-test          # Install without running test backup
    $0 uninstall          # Remove the system

EOF
}

# Main function
main() {
    local command="install"
    local enable_timers=true
    local run_test=true
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            install)
                command="install"
                shift
                ;;
            uninstall)
                command="uninstall"
                shift
                ;;
            --no-timers)
                enable_timers=false
                shift
                ;;
            --no-test)
                run_test=false
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case "$command" in
        install)
            check_root
            check_freeipa
            create_directories
            install_scripts
            install_config
            install_systemd
            configure_logrotate
            enable_services "$enable_timers"
            
            if [[ "$run_test" == "true" ]]; then
                test_backup
            fi
            
            show_summary
            ;;
        uninstall)
            check_root
            uninstall
            ;;
        *)
            error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
