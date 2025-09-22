# FreeIPA Backup Automation v2.0

A comprehensive automation solution for regular FreeIPA backups with intelligent retention management and monitoring.

## 🆕 What's New in v2.0

- **🎯 FULL/DATA Strategy**: FULL backups on Sundays, DATA backups on other days
- **🔧 Flexibility**: Manual execution support with `--type {full|data|auto}`
- **🧪 Test Mode**: `DRY_RUN=1` for simulations without execution
- **⚡ Performance**: Online DATA backups (without stopping services)
- **🔍 Enhanced Logging**: Logs to systemd journal and file
- **🔒 Security**: Rigorous validation and variable management
- **📦 Installation**: Automated script for v1.0 → v2.0 upgrade

## 🎯 Features

- **Automated Backups**: Daily backups scheduled via systemd timers
- **Retention Management**: Retention policy following DevOps best practices
- **Monitoring**: Email and webhook notifications
- **Security**: Robust error handling and automatic recovery
- **Easy Installation**: Automated installation script
- **Complete Logging**: Detailed logs with automatic rotation

## 📋 Retention Policy

By default, the system keeps:

- **Daily Backups**: 7 days
- **Weekly Backups** (Mondays): 4 weeks
- **Monthly Backups** (1st day): 12 months
- **Annual Backups** (January 1st): forever

This policy is configurable in the `config.conf` file.

## 🛠️ v2.0 Usage

### Manual Execution

```bash
# Automatic backup (FULL on Sunday, DATA on other days)
sudo /opt/sysadmin-scripts/freeipa-backup-automation/freeipa-backup.sh

# Force data-only backup
sudo /opt/sysadmin-scripts/freeipa-backup-automation/freeipa-backup.sh --type data

# Force full backup
sudo /opt/sysadmin-scripts/freeipa-backup-automation/freeipa-backup.sh --type full

# Simulate backup without execution (test)
DRY_RUN=1 /opt/sysadmin-scripts/freeipa-backup-automation/freeipa-backup.sh --type full
````

### v2.0 Timer Management

```bash
# Check status of new timers
systemctl list-timers | grep freeipa-backup

# Stop/start individual timers
sudo systemctl stop freeipa-backup-data.timer
sudo systemctl start freeipa-backup-full.timer

# View backup logs
journalctl -u freeipa-backup@data.service -n 50
journalctl -u freeipa-backup@full.service -n 50
```

### Environment Variables

Advanced customization (respecting no-override rule):

```bash
# Customize location and behavior
export BACKUP_DIR="/custom/backup/location"
export DRY_RUN="1"  # Simulation mode
export BACKUP_TYPE="full"  # Force type

# Run with customizations
sudo -E /opt/sysadmin-scripts/freeipa-backup-automation/freeipa-backup.sh
```

## 🚀 Quick Installation

### Prerequisites

* FreeIPA installed and configured
* Root access
* systemd (for scheduling)

### Fresh Installation (v2.0)

```bash
# Clone the repository
git clone <repository-url>
cd freeipa-backup-automation

# Run the v2.0 installation script
sudo ./install-v2.sh
```

### Upgrade v1.0 → v2.0

To upgrade from an existing v1.0 installation:

```bash
# In the repository directory
sudo ./install-v2.sh upgrade

# In case of problems, automatic rollback
sudo ./install-v2.sh rollback
```

📝 **What happens during upgrade:**

1. ✅ Automatic backup of current v1.0 installation
2. ✅ Installation of new script with FULL/DATA support
3. ✅ Configuration of new timers (DATA: Mon-Sat, FULL: Sun)
4. ✅ Deactivation of old daily timer
5. ✅ Testing of new configuration
6. ✅ Instant rollback possibility

### Custom Installation

```bash
# Install without activating automatic timers
sudo ./install.sh --no-timers

# Install without running test backup
sudo ./install.sh --no-test

# View installation options
./install.sh --help
```

## ⚙️ Configuration

### Configuration File

Edit `/etc/freeipa-backup-automation/config.conf` to customize:

```bash
# Backup location
BACKUP_DIR="/var/lib/ipa/backup"

# Retention policy (in days)
DAILY_RETENTION=7
WEEKLY_RETENTION=28
MONTHLY_RETENTION=365
YEARLY_RETENTION=0

# Email notifications
EMAIL_NOTIFICATIONS=true
EMAIL_TO="admin@example.com"
SMTP_SERVER="smtp.example.com"
SMTP_USER="backup@example.com"
SMTP_PASSWORD="{{SMTP_PASSWORD}}"

# Webhook (Slack, Teams, Discord, etc.)
WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Notification Setup

#### Email

```bash
EMAIL_NOTIFICATIONS=true
EMAIL_TO="admin@company.com"
SMTP_SERVER="smtp.company.com"
SMTP_PORT="587"
SMTP_USER="backup@company.com"
SMTP_PASSWORD="{{EMAIL_PASSWORD}}"
SMTP_USE_TLS=true
```

#### Webhook (Slack example)

```bash
WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
```

## 🛠️ Usage

### Manual Commands

```bash
# Run manual backup
sudo systemctl start freeipa-backup.service

# Run manual cleanup
sudo systemctl start freeipa-backup-cleanup.service

# Check backup status
sudo /usr/local/bin/backup-cleanup.sh --status

# Simulate cleanup (dry-run)
sudo /usr/local/bin/backup-cleanup.sh --dry-run
```

### Timer Management

```bash
# Check timer status
systemctl list-timers freeipa-backup*

# Start automatic timers
sudo systemctl start freeipa-backup.timer
sudo systemctl start freeipa-backup-cleanup.timer

# Stop timers
sudo systemctl stop freeipa-backup.timer
sudo systemctl stop freeipa-backup-cleanup.timer

# View next execution
systemctl status freeipa-backup.timer
```

### Monitoring

```bash
# View logs in real time
sudo journalctl -f -u freeipa-backup.service

# View cleanup logs
sudo journalctl -u freeipa-backup-cleanup.service

# View log file
sudo tail -f /var/log/freeipa-backup.log

# Test notifications
sudo /usr/local/bin/notify.sh test
```

## 🔍 Useful Commands

### Check Timer Status

```bash
# View all FreeIPA timers
systemctl list-timers | grep freeipa

# View backup timer details
systemctl status freeipa-backup.timer

# View cleanup timer details
systemctl status freeipa-backup-cleanup.timer

# View timer configuration
cat /etc/systemd/system/freeipa-backup.timer
cat /etc/systemd/system/freeipa-backup-cleanup.timer

# Verify timers are enabled
systemctl is-enabled freeipa-backup.timer freeipa-backup-cleanup.timer

# View all system timers (context)
systemctl list-timers
```

### Check Service Status

```bash
# Backup service status
systemctl status freeipa-backup.service

# Cleanup service status
systemctl status freeipa-backup-cleanup.service

# Timer run history
journalctl -u freeipa-backup.timer --no-pager -n 10
journalctl -u freeipa-backup-cleanup.timer --no-pager -n 10
```

### Backup Management

```bash
# List existing backups
sudo ls -la /var/lib/ipa/backup/

# View total size of backup directory
sudo du -sh /var/lib/ipa/backup/

# View size of each backup
sudo bash -c "cd /var/lib/ipa/backup && du -sh * 2>/dev/null"

# Check disk usage
df -h /var/lib/ipa/backup

# Run manual backup
sudo /usr/local/bin/freeipa-backup.sh

# Run manual cleanup
sudo /usr/local/bin/backup-cleanup.sh

# Simulate cleanup (dry-run)
sudo /usr/local/bin/backup-cleanup.sh --dry-run
```

### Monitoring and Logs

```bash
# View backup logs in real time
tail -f /var/log/freeipa-backup.log

# View systemd logs for backup
journalctl -u freeipa-backup.service --no-pager -f

# View systemd logs for cleanup
journalctl -u freeipa-backup-cleanup.service --no-pager -f

# View last 50 log lines
journalctl -u freeipa-backup.service --no-pager -n 50

# View logs for a specific date
journalctl -u freeipa-backup.service --since "2025-09-11" --until "2025-09-12"

# View current configuration
sudo cat /etc/freeipa-backup-automation/config.conf
```

### Diagnostics and Troubleshooting

```bash
# Check if FreeIPA is running
systemctl status ipa
ipactl status

# Test LDAP connectivity
ldapwhoami -x -H ldap://localhost

# Check script permissions
ls -la /usr/local/bin/freeipa-backup.sh
ls -la /usr/local/bin/backup-cleanup.sh

# Verify systemd configuration files
systemd-analyze verify /etc/systemd/system/freeipa-backup.service
systemd-analyze verify /etc/systemd/system/freeipa-backup.timer

# Reload systemd configuration
sudo systemctl daemon-reload

# Restart timers after changes
sudo systemctl restart freeipa-backup.timer
sudo systemctl restart freeipa-backup-cleanup.timer
```

### System Management

```bash
# Enable/disable timers
sudo systemctl enable freeipa-backup.timer
sudo systemctl disable freeipa-backup.timer

# Start/stop timers manually
sudo systemctl start freeipa-backup.timer
sudo systemctl stop freeipa-backup.timer

# Run backup service immediately (test)
sudo systemctl start freeipa-backup.service

# View next scheduled run
systemctl list-timers freeipa-backup.timer

# Check service dependencies
systemctl list-dependencies freeipa-backup.service
```

### Maintenance Commands

```bash
# Clean old journald logs
sudo journalctl --vacuum-time=30d

# Check log size
sudo du -sh /var/log/journal/ || sudo du -sh /run/log/journal/
sudo journalctl --disk-usage

# Rotate logs manually
sudo logrotate /etc/logrotate.d/freeipa-backup

# Verify logrotate configuration
sudo logrotate -d /etc/logrotate.d/freeipa-backup
```

## 📊 Default Scheduling

* **Backups**: Daily at 02:00 (with random delay up to 30min)
* **Cleanup**: Sundays at 03:00 (with random delay up to 60min)

### Customizing Schedule

Edit timer files in `/etc/systemd/system/`:

```ini
# freeipa-backup.timer
[Timer]
OnCalendar=*-*-* 02:00:00  # Change time here
RandomizedDelaySec=30min
```

After changes:

```bash
sudo systemctl daemon-reload
sudo systemctl restart freeipa-backup.timer
```

## 📁 File Structure

```
/usr/local/bin/
├── freeipa-backup.sh      # Main backup script
├── backup-cleanup.sh      # Cleanup script
└── notify.sh              # Notification script

/etc/freeipa-backup-automation/
└── config.conf            # Main configuration

/etc/systemd/system/
├── freeipa-backup.service
├── freeipa-backup.timer
├── freeipa-backup-cleanup.service
└── freeipa-backup-cleanup.timer

/var/lib/ipa/backup/
├── ipa-full-2024-01-15-020045/
├── ipa-full-2024-01-16-020122/
├── latest -> ipa-full-2024-01-16-020122/
└── ...

/var/log/
└── freeipa-backup.log     # Main log
```

## 🔧 Troubleshooting

### Backup Fails

1. Check if FreeIPA is running:

   ```bash
   sudo ipactl status
   ```

2. Check logs:

   ```bash
   sudo journalctl -u freeipa-backup.service -n 50
   ```

3. Check disk space:

   ```bash
   df -h /var/lib/ipa/backup
   ```

### Notifications Not Working

1. Test configuration:

   ```bash
   sudo /usr/local/bin/notify.sh test
   ```

2. Check SMTP config:

   ```bash
   echo "Test" | curl --ssl-reqd --url smtp://smtp.example.com:587 \
     --user user@example.com:password \
     --mail-from user@example.com \
     --mail-rcpt admin@example.com \
     --upload-file -
   ```

### Permissions

```bash
# Fix permissions if necessary
sudo chown -R root:root /var/lib/ipa/backup
sudo chmod 755 /var/lib/ipa/backup
sudo chmod +x /usr/local/bin/freeipa-backup.sh
sudo chmod +x /usr/local/bin/backup-cleanup.sh
```

### Backup Recovery

```bash
# Stop services
sudo ipactl stop

# Restore backup (example)
sudo ipa-restore /var/lib/ipa/backup/ipa-full-2024-01-15-020045

# Start services
sudo ipactl start
```

## 🔒 Security

### Implemented Best Practices

* Scripts only run as root (required for FreeIPA)
* Lock files prevent simultaneous executions
* Robust error handling
* Detailed logs for auditing
* Sensitive configs protected (600 permissions)

### Systemd Security Settings

* `NoNewPrivileges=true`
* `ProtectSystem=strict`
* `PrivateTmp=true`
* `PrivateDevices=true`
* Restrictive syscall filters

### Protecting Credentials

```bash
# Restrict config file permissions
sudo chmod 600 /etc/freeipa-backup-automation/config.conf

# Use environment variables for passwords
export SMTP_PASSWORD="your-password-here"
```

## 🔄 Updates

```bash
# Fetch latest version
git pull

# Reinstall (preserves config)
sudo ./install.sh
```

## 🗑️ Uninstallation

```bash
sudo ./install.sh uninstall
```

This removes:

* System scripts
* Systemd services
* Logrotate configuration

**Preserves**:

* Existing backups
* Configuration in `/etc/freeipa-backup-automation/`
* Logs

## 📝 Logs and Monitoring

### Log Interpretation

```bash
# Successful backup
[2024-01-15 02:00:45] [INFO] Starting FreeIPA backup process
[2024-01-15 02:01:23] [INFO] Backup completed successfully
[2024-01-15 02:01:24] [INFO] Latest backup location: /var/lib/ipa/backup/ipa-full-2024-01-15-020045
[2024-01-15 02:01:30] [INFO] FreeIPA backup process completed successfully

# Cleanup logs
[2024-01-21 03:00:15] [CLEANUP] [INFO] Starting backup cleanup process
[2024-01-21 03:00:16] [CLEANUP] [INFO] Keeping backup: ipa-full-2024-01-20-020045 (Age: 1d, Category: daily, Size: 2.1G)
[2024-01-21 03:00:17] [CLEANUP] [INFO] Removing expired backup: ipa-full-2024-01-05-020045 (Size: 2.0G)
[2024-01-21 03:00:25] [CLEANUP] [INFO] Cleanup completed: 3 removed, 0 failed, 7 kept
```

### Key Metrics

* Backup duration
* Backup sizes
* Success rate
* Space freed by cleanup

## 🆘 Support

For support:

1. Review this README
2. Check system logs
3. Contact the admin team

## 📈 Roadmap

Planned features:

* [ ] Web interface for monitoring
* [ ] Prometheus metrics
* [ ] Cloud storage backup
* [ ] Backup encryption
* [ ] Automatic integrity checks
* [ ] Grafana dashboard

---

**Note**: This system was designed specifically for FreeIPA on Fedora/CentOS/RHEL environments, but should also work on other Linux distributions with systemd.
