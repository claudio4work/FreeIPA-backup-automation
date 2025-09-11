# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Architecture Overview

This is a FreeIPA backup automation system built around bash scripts and systemd services. The system follows a modular architecture with three main components:

- **freeipa-backup.sh**: Core backup orchestration with service lifecycle management
- **backup-cleanup.sh**: Intelligent retention policy management (daily/weekly/monthly/yearly)
- **notify.sh**: Multi-channel notification system (email/webhook)

The system uses systemd timers for scheduling and includes comprehensive error handling, security hardening, and logging.

## Key Configuration

All configuration is centralized in `config.conf` with sensible defaults. The system uses a layered configuration approach:
1. Built-in defaults in scripts
2. Configuration file overrides
3. Environment variables for sensitive data

## Development Commands

### Testing and Validation

```bash
# Dry run cleanup to see what would be removed
sudo ./backup-cleanup.sh --dry-run

# Check current backup status
sudo ./backup-cleanup.sh --status

# Test backup script without systemd
sudo ./freeipa-backup.sh

# Test notification system
sudo ./notify.sh test
```

### Installation and Deployment

```bash
# Full installation with automatic timers
sudo ./install.sh

# Install without starting timers (manual control)
sudo ./install.sh --no-timers

# Install without running test backup
sudo ./install.sh --no-test

# Complete uninstall
sudo ./install.sh uninstall
```

### Service Management

```bash
# Manual service execution
sudo systemctl start freeipa-backup.service
sudo systemctl start freeipa-backup-cleanup.service

# Timer management
sudo systemctl start freeipa-backup.timer
sudo systemctl stop freeipa-backup.timer
systemctl list-timers freeipa-backup*

# Monitor logs
sudo journalctl -f -u freeipa-backup.service
sudo tail -f /var/log/freeipa-backup.log
```

## Core Architecture Patterns

### Service Orchestration
The backup script follows a careful service lifecycle pattern:
1. Check if FreeIPA is running
2. Stop services for consistent backup
3. Perform backup operation
4. Restart services
5. Trap handlers ensure services restart even on failure

### Retention Policy Implementation
The cleanup system implements a sophisticated retention strategy:
- **Daily backups**: Kept for configurable days (default: 7)
- **Weekly backups**: Monday backups kept longer (default: 28 days)
- **Monthly backups**: First-of-month backups kept longer (default: 365 days)
- **Yearly backups**: January 1st backups kept indefinitely

### Error Handling Strategy
- Lock files prevent concurrent operations
- Comprehensive logging with timestamp and severity levels
- Graceful degradation with notification alerts
- Service restart guarantees via trap handlers

### Security Hardening
SystemD services include extensive security restrictions:
- NoNewPrivileges, ProtectSystem=strict, PrivateTmp
- System call filtering and namespace restrictions
- Resource limits and scheduling controls
- Minimal filesystem access permissions

## Installation Flow

The install script performs:
1. FreeIPA presence validation
2. Directory structure creation (`/usr/local/bin`, `/etc/freeipa-backup-automation`)
3. Script installation with permission setup
4. SystemD service and timer deployment
5. Logrotate configuration
6. Optional test backup execution

Files are installed to system paths:
- Scripts: `/usr/local/bin/`
- Config: `/etc/freeipa-backup-automation/`
- SystemD units: `/etc/systemd/system/`

## Notification Architecture

The notification system supports multiple channels:
- **Email**: SMTP with TLS support using curl
- **Webhooks**: Generic JSON format compatible with Slack/Teams/Discord
- **Intelligent alerting**: Only sends notifications on completion or errors

Credentials should be configured as environment variables rather than directly in config files.

## Key Dependencies

- **ipactl** and **ipa-backup**: Core FreeIPA commands
- **systemd**: For service management and scheduling
- **curl**: For notification delivery (email and webhooks)
- **find**, **stat**, **date**: For backup categorization and retention

## Configuration Files

- `config.conf`: Main configuration with retention policies, notification settings, and system parameters
- `systemd/*.service`: Service definitions with security hardening
- `systemd/*.timer`: Scheduling configuration with randomized delays
- `/etc/logrotate.d/freeipa-backup`: Log rotation configuration

## Testing Strategy

The system includes built-in testing capabilities:
- Dry-run mode for cleanup operations
- Test notifications for configuration validation
- Status reporting for backup inventory
- Service testing during installation

When making changes, always test with dry-run mode first to validate retention logic.
