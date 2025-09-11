#!/bin/bash
#
# FreeIPA Backup Cleanup Script
# Manages backup retention according to DevOps best practices
# Retention policy: Daily (7 days), Weekly (4 weeks), Monthly (12 months), Yearly (indefinite)
#

# Source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Default values
BACKUP_DIR="/var/lib/ipa/backup"
LOG_FILE="/var/log/freeipa-backup.log"

# Default retention policy (in days)
DAILY_RETENTION=7
WEEKLY_RETENTION=28
MONTHLY_RETENTION=365
YEARLY_RETENTION=0  # 0 means keep forever

# Source config file if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEANUP] [$level] $*" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        exit 1
    fi
}

# Get backup age in days
get_backup_age() {
    local backup_path="$1"
    local backup_timestamp=$(stat -c %Y "$backup_path" 2>/dev/null)
    local current_timestamp=$(date +%s)
    
    if [[ -z "$backup_timestamp" ]]; then
        echo "0"
        return
    fi
    
    echo $(( (current_timestamp - backup_timestamp) / 86400 ))
}

# Check if backup is first of month
is_first_of_month() {
    local backup_path="$1"
    local backup_day=$(stat -c %Y "$backup_path" 2>/dev/null | xargs -I {} date -d @{} +%d)
    [[ "$backup_day" == "01" ]]
}

# Check if backup is first of week (Monday)
is_first_of_week() {
    local backup_path="$1"
    local backup_weekday=$(stat -c %Y "$backup_path" 2>/dev/null | xargs -I {} date -d @{} +%u)
    [[ "$backup_weekday" == "1" ]]
}

# Check if backup is first of year
is_first_of_year() {
    local backup_path="$1"
    local backup_date=$(stat -c %Y "$backup_path" 2>/dev/null | xargs -I {} date -d @{} +%m%d)
    [[ "$backup_date" == "0101" ]]
}

# Determine backup category based on age and date
categorize_backup() {
    local backup_path="$1"
    local age=$(get_backup_age "$backup_path")
    
    if [[ $age -le $DAILY_RETENTION ]]; then
        echo "daily"
    elif [[ $age -le $WEEKLY_RETENTION ]] && is_first_of_week "$backup_path"; then
        echo "weekly"
    elif [[ $age -le $MONTHLY_RETENTION ]] && is_first_of_month "$backup_path"; then
        echo "monthly"
    elif [[ $YEARLY_RETENTION -eq 0 ]] && is_first_of_year "$backup_path"; then
        echo "yearly"
    else
        echo "expired"
    fi
}

# Get backup size in human readable format
get_backup_size() {
    local backup_path="$1"
    du -sh "$backup_path" 2>/dev/null | cut -f1
}

# Remove expired backup
remove_backup() {
    local backup_path="$1"
    local backup_size=$(get_backup_size "$backup_path")
    
    log "INFO" "Removing expired backup: $(basename "$backup_path") (Size: $backup_size)"
    
    if [[ -d "$backup_path" ]]; then
        if rm -rf "$backup_path"; then
            log "INFO" "Successfully removed backup: $(basename "$backup_path")"
            return 0
        else
            log "ERROR" "Failed to remove backup: $(basename "$backup_path")"
            return 1
        fi
    else
        log "WARN" "Backup path does not exist: $backup_path"
        return 1
    fi
}

# Dry run mode - show what would be removed
dry_run() {
    log "INFO" "DRY RUN MODE - No backups will be actually removed"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "ERROR" "Backup directory does not exist: $BACKUP_DIR"
        return 1
    fi
    
    local total_backups=0
    local expired_backups=0
    local total_expired_size=0
    
    # Find all backup directories
    while IFS= read -r -d '' backup_path; do
        ((total_backups++))
        local backup_name=$(basename "$backup_path")
        local age=$(get_backup_age "$backup_path")
        local category=$(categorize_backup "$backup_path")
        local size=$(get_backup_size "$backup_path")
        
        if [[ "$category" == "expired" ]]; then
            ((expired_backups++))
            log "INFO" "WOULD REMOVE: $backup_name (Age: ${age}d, Size: $size)"
        else
            log "INFO" "WOULD KEEP: $backup_name (Age: ${age}d, Category: $category, Size: $size)"
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ipa-full-*" -print0 | sort -z)
    
    log "INFO" "Summary: $total_backups total backups, $expired_backups would be removed"
}

# Perform cleanup
perform_cleanup() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "ERROR" "Backup directory does not exist: $BACKUP_DIR"
        return 1
    fi
    
    log "INFO" "Starting backup cleanup process"
    log "INFO" "Retention policy: Daily=${DAILY_RETENTION}d, Weekly=${WEEKLY_RETENTION}d, Monthly=${MONTHLY_RETENTION}d, Yearly=${YEARLY_RETENTION}d"
    
    local total_backups=0
    local removed_backups=0
    local failed_removals=0
    local total_size_freed=0
    
    # Find all backup directories
    while IFS= read -r -d '' backup_path; do
        ((total_backups++))
        local backup_name=$(basename "$backup_path")
        local age=$(get_backup_age "$backup_path")
        local category=$(categorize_backup "$backup_path")
        local size=$(get_backup_size "$backup_path")
        
        if [[ "$category" == "expired" ]]; then
            if remove_backup "$backup_path"; then
                ((removed_backups++))
            else
                ((failed_removals++))
            fi
        else
            log "INFO" "Keeping backup: $backup_name (Age: ${age}d, Category: $category, Size: $size)"
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ipa-full-*" -print0 | sort -z)
    
    # Update latest symlink if it's broken
    if [[ -L "$BACKUP_DIR/latest" ]] && [[ ! -e "$BACKUP_DIR/latest" ]]; then
        log "WARN" "Latest backup symlink is broken, updating..."
        rm -f "$BACKUP_DIR/latest"
        
        # Find the most recent backup and create new symlink
        local latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ipa-full-*" -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$latest_backup" ]]; then
            ln -s "$latest_backup" "$BACKUP_DIR/latest"
            log "INFO" "Updated latest backup symlink to: $(basename "$latest_backup")"
        fi
    fi
    
    log "INFO" "Cleanup completed: $removed_backups removed, $failed_removals failed, $((total_backups - removed_backups - failed_removals)) kept"
    
    if [[ $failed_removals -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Show current backup status
show_status() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log "ERROR" "Backup directory does not exist: $BACKUP_DIR"
        return 1
    fi
    
    log "INFO" "Current backup status:"
    log "INFO" "Backup directory: $BACKUP_DIR"
    log "INFO" "Retention policy: Daily=${DAILY_RETENTION}d, Weekly=${WEEKLY_RETENTION}d, Monthly=${MONTHLY_RETENTION}d, Yearly=${YEARLY_RETENTION}d"
    
    local daily_count=0
    local weekly_count=0
    local monthly_count=0
    local yearly_count=0
    local expired_count=0
    local total_size=0
    
    echo ""
    printf "%-30s %-10s %-10s %-10s\n" "Backup Name" "Age (days)" "Category" "Size"
    printf "%-30s %-10s %-10s %-10s\n" "$(printf '%*s' 30 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')" "$(printf '%*s' 10 | tr ' ' '-')"
    
    while IFS= read -r -d '' backup_path; do
        local backup_name=$(basename "$backup_path")
        local age=$(get_backup_age "$backup_path")
        local category=$(categorize_backup "$backup_path")
        local size=$(get_backup_size "$backup_path")
        
        printf "%-30s %-10s %-10s %-10s\n" "${backup_name:0:29}" "${age}" "${category}" "${size}"
        
        case "$category" in
            daily) ((daily_count++)) ;;
            weekly) ((weekly_count++)) ;;
            monthly) ((monthly_count++)) ;;
            yearly) ((yearly_count++)) ;;
            expired) ((expired_count++)) ;;
        esac
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "ipa-full-*" -print0 | sort -z)
    
    echo ""
    log "INFO" "Summary: Daily=$daily_count, Weekly=$weekly_count, Monthly=$monthly_count, Yearly=$yearly_count, Expired=$expired_count"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

FreeIPA Backup Cleanup Script

OPTIONS:
    -d, --dry-run       Show what would be removed without actually removing
    -s, --status        Show current backup status
    -h, --help          Show this help message

Default retention policy:
    - Daily backups: kept for $DAILY_RETENTION days
    - Weekly backups (Mondays): kept for $WEEKLY_RETENTION days  
    - Monthly backups (1st of month): kept for $MONTHLY_RETENTION days
    - Yearly backups (Jan 1st): kept indefinitely

Configuration can be overridden in: $CONFIG_FILE
EOF
}

# Main function
main() {
    local dry_run_mode=false
    local status_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dry-run)
                dry_run_mode=true
                shift
                ;;
            -s|--status)
                status_mode=true
                shift
                ;;
            -h|--help)
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
    
    # Check if running as root
    check_root
    
    if $status_mode; then
        show_status
    elif $dry_run_mode; then
        dry_run
    else
        perform_cleanup
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
