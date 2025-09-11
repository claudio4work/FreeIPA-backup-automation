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
