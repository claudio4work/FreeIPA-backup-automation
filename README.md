# FreeIPA Backup Automation

Uma solução completa de automatização para backups regulares do FreeIPA com gestão inteligente de retenção e monitorização.

## 🎯 Funcionalidades

- **Backup Automatizado**: Backups diários programados via systemd timers
- **Gestão de Retenção**: Política de retenção seguindo boas práticas DevOps
- **Monitorização**: Notificações por email e webhook
- **Segurança**: Tratamento de erros robusto e recuperação automática
- **Facilidade de Instalação**: Script de instalação automatizada
- **Logging Completo**: Logs detalhados com rotação automática

## 📋 Política de Retenção

Por defeito, o sistema mantém:

- **Backups Diários**: 7 dias
- **Backups Semanais** (segundas-feiras): 4 semanas
- **Backups Mensais** (dia 1): 12 meses
- **Backups Anuais** (1 de Janeiro): para sempre

Esta política é configurável no ficheiro `config.conf`.

## 🚀 Instalação Rápida

### Pré-requisitos

- FreeIPA instalado e configurado
- Acesso root
- systemd (para agendamento)

### Instalação

```bash
# Clone o repositório
git clone <repository-url>
cd freeipa-backup-automation

# Execute o script de instalação
sudo ./install.sh
```

O script de instalação irá:
1. Verificar se o FreeIPA está instalado
2. Copiar os scripts para `/usr/local/bin/`
3. Configurar os serviços systemd
4. Configurar a rotação de logs
5. Executar um backup de teste
6. Ativar os timers automáticos

### Instalação Personalizada

```bash
# Instalar sem ativar os timers automáticos
sudo ./install.sh --no-timers

# Instalar sem executar backup de teste
sudo ./install.sh --no-test

# Ver opções de instalação
./install.sh --help
```

## ⚙️ Configuração

### Ficheiro de Configuração

Edite `/etc/freeipa-backup-automation/config.conf` para personalizar:

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

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o ficheiro LICENSE para detalhes.

## 🆘 Suporte

Para suporte:

1. Consulte este README
2. Verifique os logs do sistema
3. Abra uma issue no repositório
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
