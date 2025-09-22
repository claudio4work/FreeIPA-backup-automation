#!/usr/bin/env bash
#
# FreeIPA Backup Script v2.0
# Performs automated backup of FreeIPA server with FULL/DATA support
# Supports:
#   - FULL backups (complete system) on Sundays  
#   - DATA backups (data only) on weekdays
#   - AUTO mode (detects day of week automatically)
#   - DRY_RUN mode for testing
#   - Manual type selection
#

set -euo pipefail
umask 077

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Default values - only set if not already defined (following rule)
if [ -z "${BACKUP_DIR+x}" ]; then BACKUP_DIR="/var/lib/ipa/backup"; fi
if [ -z "${LOG_FILE+x}" ]; then LOG_FILE="/var/log/freeipa-backup.log"; fi
if [ -z "${LOCK_FILE+x}" ]; then LOCK_FILE="/var/run/freeipa-backup.lock"; fi
if [ -z "${BACKUP_CMD+x}" ]; then BACKUP_CMD="/usr/sbin/ipa-backup"; fi
if [ -z "${BACKUP_TYPE+x}" ]; then BACKUP_TYPE="auto"; fi
if [ -z "${ONLINE_FLAG+x}" ]; then ONLINE_FLAG="--online"; fi
if [ -z "${VERBOSE_FLAG+x}" ]; then VERBOSE_FLAG="-v"; fi
if [ -z "${DRY_RUN+x}" ]; then DRY_RUN="0"; fi

# Source config file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Usage function
usage() {
    cat << EOF
Uso: $0 [OPTIONS]

OPÇÕES:
  --type TIPO     Tipo de backup: full, data ou auto (padrão: auto)
  -h, --help      Mostrar esta ajuda

TIPOS DE BACKUP:
  full            Backup completo do sistema (sem --data)
  data            Backup apenas dos dados (com --data)  
  auto            Automático: FULL aos domingos, DATA nos outros dias

VARIÁVEIS DE AMBIENTE:
  BACKUP_DIR      Diretório dos backups (padrão: /var/lib/ipa/backup)
  BACKUP_CMD      Comando ipa-backup (padrão: /usr/sbin/ipa-backup)
  BACKUP_TYPE     Tipo padrão (padrão: auto)
  DRY_RUN         Modo teste, só mostra comandos (padrão: 0)
  ONLINE_FLAG     Flag --online (padrão: --online)
  VERBOSE_FLAG    Flag verbose (padrão: -v)

EXEMPLOS:
  $0                          # Backup automático (FULL dom, DATA outros)
  $0 --type data              # Backup apenas dados
  $0 --type full              # Backup completo
  DRY_RUN=1 $0 --type data    # Teste sem executar

EOF
    exit 1
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --type)
                shift
                if [ $# -eq 0 ]; then
                    echo "Erro: --type requer um argumento (full|data|auto)"
                    usage
                fi
                BACKUP_TYPE="$1"
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Erro: Argumento inválido: $1"
                usage
                ;;
        esac
        shift
    done
}

# Detect backup type based on day of week (auto mode)
detect_type() {
    if [ "$BACKUP_TYPE" = "auto" ]; then
        local dow
        dow=$(date +%u)  # 1=Monday ... 7=Sunday
        if [ "$dow" -eq 7 ]; then
            BACKUP_TYPE="full"
        else
            BACKUP_TYPE="data"
        fi
    fi
    
    # Validate backup type
    case "$BACKUP_TYPE" in
        full|data)
            # Valid types
            ;;
        *)
            echo "Erro: Tipo de backup inválido: $BACKUP_TYPE"
            echo "Tipos válidos: full, data, auto"
            exit 1
            ;;
    esac
}

# Find latest backup of given type
latest_backup() {
    local backup_type="$1"
    # List directories/files matching pattern, sort by modification time, get most recent
    ls -1dt "$BACKUP_DIR"/ipa-${backup_type}-* 2>/dev/null | head -n1 || true
}

# Enhanced logging function with syslog support
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Log to file
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # Log to syslog/journal
    logger -t "freeipa-backup" "[$level] $message"
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

# Build backup command based on type
build_backup_command() {
    local cmd="$BACKUP_CMD $VERBOSE_FLAG $ONLINE_FLAG"
    
    # Add --data flag for DATA backups only
    if [ "$BACKUP_TYPE" = "data" ]; then
        cmd="$cmd --data"
    fi
    
    echo "$cmd"
}

# Perform backup with FULL/DATA support
perform_backup() {
    local backup_name="ipa-backup-$(date +%Y%m%d-%H%M%S)"
    log "INFO" "Starting $BACKUP_TYPE backup: $backup_name"
    
    # Ensure backup directory exists
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "INFO" "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || error_exit "Failed to create backup directory"
    fi
    
    # Build the backup command
    local backup_command
    backup_command=$(build_backup_command)
    
    log "INFO" "Executing: $backup_command"
    
    # Perform the backup (with DRY_RUN support)
    if [ "$DRY_RUN" = "1" ]; then
        log "INFO" "[DRY_RUN] Would execute: $backup_command"
        log "INFO" "[DRY_RUN] Backup simulation completed"
    else
        if eval "$backup_command"; then
            log "INFO" "Backup completed successfully"
            
            # Find the most recent backup directory of the correct type
            local latest_backup
            latest_backup=$(latest_backup "$BACKUP_TYPE")
            
            if [[ -n "$latest_backup" ]]; then
                log "INFO" "Latest $BACKUP_TYPE backup location: $latest_backup"
                
                # Create a symlink to the latest backup
                if ln -sfn "$latest_backup" "$BACKUP_DIR/latest"; then
                    log "INFO" "Updated latest backup symlink"
                else
                    log "WARN" "Failed to create latest backup symlink"
                fi
                
                # Get backup size
                local backup_size
                backup_size=$(du -sh "$latest_backup" 2>/dev/null | cut -f1 || echo "unknown")
                log "INFO" "Backup size: $backup_size"
                
                # Log backup type and location for monitoring
                logger -t "freeipa-backup" "Backup completed: type=$BACKUP_TYPE, location=$latest_backup, size=$backup_size"
            else
                log "WARN" "Could not find the created backup directory"
            fi
        else
            error_exit "Backup failed"
        fi
    fi
}

# Main function
main() {
    # Parse command line arguments first
    parse_args "$@"
    
    # Detect/set backup type based on arguments or day of week
    detect_type
    
    log "INFO" "Starting FreeIPA $BACKUP_TYPE backup process"
    
    # Show configuration for transparency
    log "INFO" "Configuration: BACKUP_TYPE=$BACKUP_TYPE, BACKUP_DIR=$BACKUP_DIR, DRY_RUN=$DRY_RUN"
    
    # Pre-flight checks
    check_root
    check_lock
    check_freeipa
    
    # For FULL backups, we need to stop services (can't use --online)
    # For DATA backups, we can keep services running with --online
    local need_service_stop=false
    if [ "$BACKUP_TYPE" = "full" ]; then
        need_service_stop=true
        # Remove --online flag for full backups
        ONLINE_FLAG=""
        log "INFO" "Full backup mode: will stop services during backup"
    else
        log "INFO" "Data backup mode: services will remain online"
    fi
    
    # Store initial FreeIPA status
    local ipa_was_running=false
    if check_ipa_status; then
        ipa_was_running=true
    fi
    
    # Safe cleanup function that doesn't rely on trap context
    cleanup_with_restart() {
        cleanup
        if [ "$ipa_was_running" = "true" ] && [ "$need_service_stop" = "true" ] && ! check_ipa_status; then
            log "WARN" "Attempting to restart FreeIPA services..."
            start_ipa
        fi
    }
    
    # Trap to ensure cleanup on exit (simple, no variable dependencies)
    trap 'cleanup' EXIT
    
    # Perform backup process
    if [ "$need_service_stop" = "true" ] && [ "$ipa_was_running" = "true" ]; then
        stop_ipa
    fi
    
    perform_backup
    
    if [ "$need_service_stop" = "true" ] && [ "$ipa_was_running" = "true" ]; then
        start_ipa
    fi
    
    # Show latest backup info
    local latest
    latest=$(latest_backup "$BACKUP_TYPE")
    if [[ -n "$latest" ]]; then
        log "INFO" "Latest $BACKUP_TYPE backup: $latest"
    fi
    
    # Disable trap since we're handling cleanup manually
    trap - EXIT
    
    # Manual cleanup with service restart if needed
    cleanup_with_restart
    
    log "INFO" "FreeIPA $BACKUP_TYPE backup process completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
