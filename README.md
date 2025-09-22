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

By default, the system maintains:

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
```

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

- FreeIPA installed and configured
- Root access
- systemd (for scheduling)

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
4. ✅ Deactivation of old timer (daily)
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
# Localização dos backups
BACKUP_DIR="/var/lib/ipa/backup"

# Política de retenção (em dias)
DAILY_RETENTION=7
WEEKLY_RETENTION=28
MONTHLY_RETENTION=365
YEARLY_RETENTION=0

# Notificações por email
EMAIL_NOTIFICATIONS=true
EMAIL_TO="admin@example.com"
SMTP_SERVER="smtp.example.com"
SMTP_USER="backup@example.com"
SMTP_PASSWORD="{{SMTP_PASSWORD}}"

# Webhook (Slack, Teams, Discord, etc.)
WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Configuração de Notificações

#### Email
```bash
EMAIL_NOTIFICATIONS=true
EMAIL_TO="admin@empresa.com"
SMTP_SERVER="smtp.empresa.com"
SMTP_PORT="587"
SMTP_USER="backup@empresa.com"
SMTP_PASSWORD="{{EMAIL_PASSWORD}}"
SMTP_USE_TLS=true
```

#### Webhook (Slack exemplo)
```bash
WEBHOOK_URL="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
```

## 🛠️ Utilização

### Comandos Manuais

```bash
# Executar backup manual
sudo systemctl start freeipa-backup.service

# Executar limpeza manual
sudo systemctl start freeipa-backup-cleanup.service

# Ver estado dos backups
sudo /usr/local/bin/backup-cleanup.sh --status

# Simular limpeza (dry-run)
sudo /usr/local/bin/backup-cleanup.sh --dry-run
```

### Gestão dos Timers

```bash
# Ver estado dos timers
systemctl list-timers freeipa-backup*

# Iniciar timers automáticos
sudo systemctl start freeipa-backup.timer
sudo systemctl start freeipa-backup-cleanup.timer

# Parar timers
sudo systemctl stop freeipa-backup.timer
sudo systemctl stop freeipa-backup-cleanup.timer

# Ver próxima execução
systemctl status freeipa-backup.timer
```

### Monitorização

```bash
# Ver logs em tempo real
sudo journalctl -f -u freeipa-backup.service

# Ver logs da limpeza
sudo journalctl -u freeipa-backup-cleanup.service

# Ver arquivo de log
sudo tail -f /var/log/freeipa-backup.log

# Testar notificações
sudo /usr/local/bin/notify.sh test
```

## 🔍 Comandos Úteis

### Verificar Status dos Timers

```bash
# Ver todos os timers FreeIPA
systemctl list-timers | grep freeipa

# Ver detalhes do timer de backup
systemctl status freeipa-backup.timer

# Ver detalhes do timer de limpeza
systemctl status freeipa-backup-cleanup.timer

# Ver configuração dos timers
cat /etc/systemd/system/freeipa-backup.timer
cat /etc/systemd/system/freeipa-backup-cleanup.timer

# Verificar se os timers estão habilitados
systemctl is-enabled freeipa-backup.timer freeipa-backup-cleanup.timer

# Ver todos os timers do sistema (contexto)
systemctl list-timers
```

### Verificar Status dos Serviços

```bash
# Status do serviço de backup
systemctl status freeipa-backup.service

# Status do serviço de limpeza
systemctl status freeipa-backup-cleanup.service

# Histórico de execuções dos timers
journalctl -u freeipa-backup.timer --no-pager -n 10
journalctl -u freeipa-backup-cleanup.timer --no-pager -n 10
```

### Gestão de Backups

```bash
# Listar backups existentes
sudo ls -la /var/lib/ipa/backup/

# Ver tamanho total do diretório de backups
sudo du -sh /var/lib/ipa/backup/

# Ver tamanho de cada backup individualmente
sudo bash -c "cd /var/lib/ipa/backup && du -sh * 2>/dev/null"

# Verificar espaço em disco
df -h /var/lib/ipa/backup

# Executar backup manual
sudo /usr/local/bin/freeipa-backup.sh

# Executar limpeza manual
sudo /usr/local/bin/backup-cleanup.sh

# Simular limpeza (dry-run)
sudo /usr/local/bin/backup-cleanup.sh --dry-run
```

### Monitorização e Logs

```bash
# Ver logs do backup em tempo real
tail -f /var/log/freeipa-backup.log

# Ver logs do systemd para backup
journalctl -u freeipa-backup.service --no-pager -f

# Ver logs do systemd para limpeza
journalctl -u freeipa-backup-cleanup.service --no-pager -f

# Ver últimas 50 linhas dos logs
journalctl -u freeipa-backup.service --no-pager -n 50

# Ver logs de uma data específica
journalctl -u freeipa-backup.service --since "2025-09-11" --until "2025-09-12"

# Ver configuração atual
sudo cat /etc/freeipa-backup-automation/config.conf
```

### Diagnósticos e Troubleshooting

```bash
# Verificar se FreeIPA está a funcionar
systemctl status ipa
ipactl status

# Testar conectividade LDAP
ldapwhoami -x -H ldap://localhost

# Verificar permissões dos scripts
ls -la /usr/local/bin/freeipa-backup.sh
ls -la /usr/local/bin/backup-cleanup.sh

# Verificar integridade dos ficheiros de configuração systemd
systemd-analyze verify /etc/systemd/system/freeipa-backup.service
systemd-analyze verify /etc/systemd/system/freeipa-backup.timer

# Recarregar configuração systemd após alterações
sudo systemctl daemon-reload

# Reiniciar timers após alterações
sudo systemctl restart freeipa-backup.timer
sudo systemctl restart freeipa-backup-cleanup.timer
```

### Gestão do Sistema

```bash
# Habilitar/desabilitar timers
sudo systemctl enable freeipa-backup.timer
sudo systemctl disable freeipa-backup.timer

# Iniciar/parar timers manualmente
sudo systemctl start freeipa-backup.timer
sudo systemctl stop freeipa-backup.timer

# Executar serviço de backup imediatamente (para teste)
sudo systemctl start freeipa-backup.service

# Ver próxima execução programada
systemctl list-timers freeipa-backup.timer

# Verificar dependências do serviço
systemctl list-dependencies freeipa-backup.service
```

### Comandos de Manutenção

```bash
# Limpar logs antigos do journald
sudo journalctl --vacuum-time=30d

# Verificar tamanho dos logs (localização pode variar)
# Em sistemas com journald persistente:
sudo du -sh /var/log/journal/
# Em sistemas com journald em memória (mais comum):
sudo du -sh /run/log/journal/
# Ou usar o comando que funciona em qualquer configuração:
sudo journalctl --disk-usage

# Rotacionar logs manualmente
sudo logrotate /etc/logrotate.d/freeipa-backup

# Verificar configuração do logrotate
sudo logrotate -d /etc/logrotate.d/freeipa-backup
```

## 📊 Agendamento Padrão

- **Backups**: Diariamente às 02:00 (com delay aleatório até 30min)
- **Limpeza**: Domingos às 03:00 (com delay aleatório até 60min)

### Personalizar Agendamento

Edite os ficheiros timer em `/etc/systemd/system/`:

```ini
# freeipa-backup.timer
[Timer]
OnCalendar=*-*-* 02:00:00  # Alterar hora aqui
RandomizedDelaySec=30min
```

Após alterações:
```bash
sudo systemctl daemon-reload
sudo systemctl restart freeipa-backup.timer
```

## 📁 Estrutura de Ficheiros

```
/usr/local/bin/
├── freeipa-backup.sh      # Script principal de backup
├── backup-cleanup.sh      # Script de limpeza
└── notify.sh              # Script de notificações

/etc/freeipa-backup-automation/
└── config.conf            # Configuração principal

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
└── freeipa-backup.log     # Log principal
```

## 🔧 Resolução de Problemas

### Backup Falha

1. Verificar se o FreeIPA está a correr:
   ```bash
   sudo ipactl status
   ```

2. Verificar logs:
   ```bash
   sudo journalctl -u freeipa-backup.service -n 50
   ```

3. Verificar espaço em disco:
   ```bash
   df -h /var/lib/ipa/backup
   ```

### Notificações Não Funcionam

1. Testar configuração:
   ```bash
   sudo /usr/local/bin/notify.sh test
   ```

2. Verificar configuração SMTP:
   ```bash
   # Teste manual com curl
   echo "Test" | curl --ssl-reqd --url smtp://smtp.exemplo.com:587 \
     --user usuario@exemplo.com:password \
     --mail-from usuario@exemplo.com \
     --mail-rcpt admin@exemplo.com \
     --upload-file -
   ```

### Permissões

```bash
# Corrigir permissões se necessário
sudo chown -R root:root /var/lib/ipa/backup
sudo chmod 755 /var/lib/ipa/backup
sudo chmod +x /usr/local/bin/freeipa-backup.sh
sudo chmod +x /usr/local/bin/backup-cleanup.sh
```

### Recovery de Backup

Para restaurar um backup do FreeIPA:

```bash
# Parar serviços
sudo ipactl stop

# Restaurar backup (exemplo)
sudo ipa-restore /var/lib/ipa/backup/ipa-full-2024-01-15-020045

# Iniciar serviços
sudo ipactl start
```

## 🔒 Segurança

### Boas Práticas Implementadas

- Scripts executam apenas como root (necessário para FreeIPA)
- Lock files previnem execuções simultâneas
- Tratamento robusto de erros
- Logs detalhados para auditoria
- Configurações sensíveis protegidas (600 permissions)

### Configurações de Segurança SystemD

- `NoNewPrivileges=true`
- `ProtectSystem=strict`
- `PrivateTmp=true`
- `PrivateDevices=true`
- Filtros de system calls restritivos

### Proteger Credenciais

```bash
# Configurar permissões restritivas
sudo chmod 600 /etc/freeipa-backup-automation/config.conf

# Usar variáveis de ambiente para passwords
export SMTP_PASSWORD="sua-password-aqui"
# Em vez de colocar diretamente no config.conf
```

## 🔄 Atualizações

Para atualizar o sistema:

```bash
# Baixar nova versão
git pull

# Reinstalar (preserva configuração)
sudo ./install.sh
```

## 🗑️ Desinstalação

```bash
sudo ./install.sh uninstall
```

Este comando remove:
- Scripts do sistema
- Serviços systemd
- Configuração logrotate

**Preserva**:
- Backups existentes
- Configuração em `/etc/freeipa-backup-automation/`
- Logs

## 📝 Logs e Monitorização

### Interpretar Logs

```bash
# Backup bem-sucedido
[2024-01-15 02:00:45] [INFO] Starting FreeIPA backup process
[2024-01-15 02:01:23] [INFO] Backup completed successfully
[2024-01-15 02:01:24] [INFO] Latest backup location: /var/lib/ipa/backup/ipa-full-2024-01-15-020045
[2024-01-15 02:01:30] [INFO] FreeIPA backup process completed successfully

# Limpeza de backups
[2024-01-21 03:00:15] [CLEANUP] [INFO] Starting backup cleanup process
[2024-01-21 03:00:16] [CLEANUP] [INFO] Keeping backup: ipa-full-2024-01-20-020045 (Age: 1d, Category: daily, Size: 2.1G)
[2024-01-21 03:00:17] [CLEANUP] [INFO] Removing expired backup: ipa-full-2024-01-05-020045 (Size: 2.0G)
[2024-01-21 03:00:25] [CLEANUP] [INFO] Cleanup completed: 3 removed, 0 failed, 7 kept
```

### Métricas Importantes

- Tempo de backup
- Tamanho dos backups
- Taxa de sucesso
- Espaço libertado pela limpeza

## 🆘 Suporte

Para suporte:

1. Consulte este README
2. Verifique os logs do sistema
4. Contacte a equipa de administração

## 📈 Roadmap

Funcionalidades planeadas:

- [ ] Interface web para monitorização
- [ ] Métricas Prometheus
- [ ] Backup para cloud storage
- [ ] Encriptação de backups
- [ ] Testes de integridade automáticos
- [ ] Dashboard Grafana

---

**Nota**: Este sistema foi desenhado especificamente para FreeIPA em ambientes Fedora/CentOS/RHEL, mas deve funcionar em outras distribuições Linux com systemd.
