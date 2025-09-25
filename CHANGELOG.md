# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2025-09-25

### Fixed
- **CRITICAL**: Fixed systemd service ReadWritePaths configuration that was preventing backups from running
  - Added `/var/lib` to allow FreeIPA to write LDIF files and auth backup files  
  - Added `/etc/dirsrv` to allow DirectoryServer configuration updates during full backups
  - This resolves "Read-only file system" errors that were causing backup failures
  - Issue affected both DATA backups (Mon-Sat 02:00) and FULL backups (Sun 02:00)

### Changed  
- Updated systemd security configuration while maintaining strict protection
- Improved ReadWritePaths to include all directories required by FreeIPA backup operations

### Technical Details
The previous configuration:
```
ReadWritePaths=/var/lib/ipa/backup /var/log /var/run
```

Has been updated to:
```  
ReadWritePaths=/var/lib /etc/dirsrv /var/log /var/run
```

This change resolves systemd's `ProtectSystem=strict` blocking FreeIPA's internal backup operations while maintaining security by only allowing writes to essential directories.

## [2.0.0] - 2025-09-22

### Added
- Complete rewrite with FULL/DATA backup support
- Automatic scheduling: FULL on Sundays, DATA on weekdays  
- Enhanced systemd integration with template services
- Improved logging and error handling
- DRY_RUN mode for testing
- Backup size reporting and symlink management
- Resource limits and timeout settings
- Enhanced security with systemd hardening

### Changed
- Migrated from single service to template-based architecture
- Updated timer configuration for better scheduling
- Improved script structure and error handling

### Removed
- Legacy v1.0.0 single backup approach
- Old cron-based scheduling (replaced with systemd timers)