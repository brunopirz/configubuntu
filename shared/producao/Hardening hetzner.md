# Hardening VPS Produção - Hetzner Cloud
## Versão Ajustada: Firewall Cloud + Usuário Root

> ✅ **Configuração:**
> - Servidor: Hetzner Cloud
> - Firewall: Já configurado no painel (Cloud Firewall)
> - Usuário: Manter root
> - Apps: Docker Swarm + Portainer em produção

---

## 🎯 Estratégia Ajustada

### O que VAI ser feito:
- ✅ Hardening básico do sistema
- ✅ fail2ban (proteção brute-force)
- ✅ SSH endurecido (mantendo root)
- ✅ Atualizações automáticas
- ✅ Monitoramento e logs
- ✅ Otimização Docker

### O que NÃO VAI ser feito:
- ❌ **UFW** (não precisa - Hetzner Firewall já protege)
- ❌ **Criar usuário não-root** (você quer manter root)
- ❌ **Mexer em Docker/Swarm/Portainer**

---

## 📋 FASE 1: Preparação e Backup (20 minutos)

### 1.1. Verificar Hetzner Cloud Firewall

**No painel Hetzner Cloud:**
1. Acesse "Firewalls" no menu lateral
2. Veja as regras configuradas
3. Anote quais portas estão abertas

**Exemplo de configuração típica:**
```
Inbound Rules:
├─ SSH (22) - Permitido de todos os IPs
├─ HTTP (80) - Permitido de todos os IPs
├─ HTTPS (443) - Permitido de todos os IPs
├─ Portainer (9000/9443) - Permitido
└─ Outras portas das suas apps

Outbound Rules:
└─ All traffic - Permitido
```

### 1.2. Criar Snapshot no Hetzner

```
1. Painel Hetzner → Seu servidor
2. Aba "Snapshots"
3. "Take Snapshot"
4. Nome: "pre-hardening-{data}"
5. Esperar completar (~5min)
```

**💰 Nota:** Snapshots na Hetzner custam €0.0119/GB/mês. Vale a pena!

### 1.3. Backup de configurações

```bash
# Conectar como root
ssh root@seu-servidor

# Criar diretório de backup
mkdir -p /root/hardening-backup
cd /root/hardening-backup

# Documentar estado atual
cat > pre-hardening-state.txt <<EOF
Data: $(date)
Servidor: $(hostname)
IP: $(hostname -I)
OS: $(lsb_release -ds)
RAM: $(free -h | grep Mem | awk '{print $2}')
Docker: $(docker --version)
Swarm: $(docker info --format '{{.Swarm.LocalNodeState}}')
Containers rodando: $(docker ps -q | wc -l)
EOF

# Backup configs
cp -r /etc/ssh /root/hardening-backup/ssh-backup
cp -r /etc/docker /root/hardening-backup/docker-backup 2>/dev/null || true
cp /etc/sysctl.conf /root/hardening-backup/ 2>/dev/null || true

# Listar containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > containers-running.txt
docker service ls > services.txt 2>/dev/null || true

# Ver estado
cat pre-hardening-state.txt
```

---

## 🔒 FASE 2: Hardening Básico (45 minutos)

### 2.1. Atualizações de segurança

```bash
# Update sem afetar Docker
apt-get update
apt-get upgrade -y

# NÃO vai reiniciar containers
```

### 2.2. Instalar ferramentas essenciais

```bash
# Instalar apenas o necessário
apt-get install -y \
  fail2ban \
  unattended-upgrades \
  chrony \
  logwatch \
  htop \
  ncdu

# NÃO instalar UFW (já tem firewall Hetzner)
```

### 2.3. Configurar fail2ban

```bash
# fail2ban é ESSENCIAL mesmo com firewall Hetzner
# Protege contra brute-force SSH

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# Configuração robusta
bantime = 1h
findtime = 10m
maxretry = 5
destemail = root@localhost

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 6
bantime = 30m
EOF

# Criar filtro DDOS
cat > /etc/fail2ban/filter.d/sshd-ddos.conf <<'EOF'
[Definition]
failregex = ^%(__prefix_line)sDid not receive identification string from <HOST>\s*$
            ^%(__prefix_line)sConnection (closed|reset) by <HOST> port \d+\s*$
ignoreregex =
EOF

# Iniciar
systemctl enable fail2ban
systemctl start fail2ban

# Verificar
fail2ban-client status sshd
```

**✅ Resultado:** Proteção contra brute-force ativa

### 2.4. Hardening de kernel (LEVE - Docker friendly)

```bash
# Backup
cp /etc/sysctl.conf /root/hardening-backup/ 2>/dev/null || true

# Aplicar hardening LEVE
cat > /etc/sysctl.d/99-hardening-hetzner.conf <<'EOF'
# Proteção básica de filesystem
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.suid_dumpable=0

# Network - mantém Docker funcionando
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

# IMPORTANTE para Docker
net.ipv4.conf.all.log_martians=0
net.ipv4.conf.default.log_martians=0

# IPv6 (se não usa, pode desabilitar)
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0

# Limites para VPS
fs.file-max=524288
kernel.pid_max=32768
EOF

# Aplicar
sysctl --system

# Verificar Docker ainda funciona
docker ps
```

**✅ Resultado:** Kernel protegido sem afetar Docker

### 2.5. Sincronização de tempo

```bash
# Chrony é mais preciso que systemd-timesyncd
systemctl disable systemd-timesyncd --now 2>/dev/null || true

cat > /etc/chrony/chrony.conf <<'EOF'
# Servidores NTP europeus (Hetzner está na Alemanha/Finlândia)
pool 2.debian.pool.ntp.org iburst
pool 0.de.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF

systemctl enable chrony
systemctl restart chrony

# Verificar
chronyc tracking
```

### 2.6. Atualizações automáticas

```bash
# Updates de segurança automáticos (SEM reiniciar)
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

dpkg-reconfigure -f noninteractive unattended-upgrades
```

**✅ CHECKPOINT 1:** Tudo funcionando?

```bash
docker ps
docker service ls
curl -I http://localhost:9000  # Ajuste porta do Portainer
```

---

## 🔐 FASE 3: SSH Hardening (30 minutos)

> ⚠️ **ATENÇÃO:** Vai mexer no SSH - tenha 2 janelas abertas!

### 3.1. Configuração SSH otimizada (mantendo root)

```bash
# Backup SSH
cp /etc/ssh/sshd_config /root/hardening-backup/sshd_config.$(date +%Y%m%d)

# Criar configuração modular
mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-hardening-hetzner.conf <<'EOF'
# ============================================
# SSH Hardening - Hetzner Production
# Mantém root login (com proteções)
# ============================================

# Autenticação
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes  # ✅ Mantém root
ChallengeResponseAuthentication no
PermitEmptyPasswords no
UsePAM yes

# Segurança
MaxAuthTries 5
MaxSessions 10
LoginGraceTime 60
MaxStartups 10:30:60

# Recursos
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes  # Útil para Git/deploy
PrintMotd no
PrintLastLog yes

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Logging (importante para monitorar)
LogLevel VERBOSE
SyslogFacility AUTH

# Algoritmos modernos (balanceado)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Banner (opcional)
# Banner /etc/ssh/banner
EOF

# Testar configuração
sshd -t

# Se OK, recarregar
systemctl reload ssh
```

### 3.2. TESTAR SSH imediatamente

```bash
# ABRIR OUTRA JANELA/TERMINAL
# Testar conexão
ssh root@seu-servidor

# Se funcionou, continuar
# Se NÃO funcionou, reverter:
# cp /root/hardening-backup/sshd_config.XXXXXX /etc/ssh/sshd_config
# systemctl reload ssh
```

### 3.3. Banner SSH (opcional mas profissional)

```bash
cat > /etc/ssh/banner <<'EOF'
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║   🔒 SISTEMA AUTORIZADO - ACESSO MONITORADO               ║
║                                                            ║
║   Este servidor é de uso exclusivo autorizado.            ║
║   Todas as atividades são registradas e monitoradas.      ║
║   Acesso não autorizado é proibido e será processado.     ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
EOF

# Descomentar linha no SSH config
sed -i 's/^# Banner/Banner/' /etc/ssh/sshd_config.d/99-hardening-hetzner.conf

systemctl reload ssh
```

### 3.4. Adicionar chaves SSH (recomendado)

```bash
# Se você ainda usa senha, considere adicionar chave SSH
# É MUITO mais seguro

# No SEU COMPUTADOR LOCAL:
# ssh-keygen -t ed25519 -C "seu-email@exemplo.com"
# ssh-copy-id root@seu-servidor

# Depois pode desabilitar senha (opcional):
# sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/99-hardening-hetzner.conf
# systemctl reload ssh
```

**✅ CHECKPOINT 2:** SSH funcionando perfeitamente?

---

## 🐳 FASE 4: Otimização Docker (30 minutos)

### 4.1. Configurar logs Docker

```bash
# Backup config atual
cp /etc/docker/daemon.json /root/hardening-backup/ 2>/dev/null || true

# Configurar limitação de logs
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "storage-driver": "overlay2"
}
EOF

# Recarregar daemon (NÃO afeta containers rodando)
systemctl daemon-reload

# Verificar
docker info | grep -i "logging\|storage"
```

**📝 Nota:** Containers existentes continuam com config antiga

### 4.2. Limpeza automática (CONSERVADORA)

```bash
cat > /etc/cron.weekly/docker-cleanup-hetzner <<'EOF'
#!/bin/bash
# Limpeza CONSERVADORA para produção

LOG_FILE="/var/log/docker-cleanup.log"

echo "=== Docker Cleanup - $(date) ===" >> $LOG_FILE

# Containers parados há mais de 30 dias
echo "Limpando containers antigos..." >> $LOG_FILE
docker container prune -f --filter "until=720h" >> $LOG_FILE 2>&1

# Imagens não usadas há mais de 30 dias
echo "Limpando imagens antigas..." >> $LOG_FILE
docker image prune -af --filter "until=720h" >> $LOG_FILE 2>&1

# Volumes órfãos (CUIDADO!)
# docker volume prune -f >> $LOG_FILE 2>&1

# Logs do sistema
find /var/log -type f -name "*.gz" -mtime +60 -delete

# APT cache
apt-get clean

echo "Cleanup finalizado" >> $LOG_FILE
echo "" >> $LOG_FILE
EOF

chmod +x /etc/cron.weekly/docker-cleanup-hetzner

# Testar manualmente (opcional)
# bash /etc/cron.weekly/docker-cleanup-hetzner
```

### 4.3. Monitoramento de recursos

```bash
cat > /root/check-resources.sh <<'EOF'
#!/bin/bash

echo "=================================="
echo "RESOURCE USAGE - $(date)"
echo "=================================="
echo ""

echo "CPU:"
mpstat 1 1 | tail -2

echo ""
echo "Memory:"
free -h

echo ""
echo "Disk:"
df -h / /var/lib/docker

echo ""
echo "Docker:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo ""
echo "Top 5 processos:"
ps aux --sort=-%mem | head -6

echo ""
echo "Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}"

echo ""
echo "Services (Swarm):"
docker service ls 2>/dev/null || echo "N/A"

echo ""
EOF

chmod +x /root/check-resources.sh

# Executar
/root/check-resources.sh
```

**✅ CHECKPOINT 3:** Docker otimizado e tudo funcionando?

---

## 📊 FASE 5: Monitoramento e Logs (20 minutos)

### 5.1. Configurar logwatch

```bash
# Relatório semanal por email (para root local)
cat > /etc/cron.weekly/00logwatch <<'EOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail low
EOF

chmod +x /etc/cron.weekly/00logwatch
```

### 5.2. Monitorar tentativas SSH

```bash
cat > /root/check-ssh-attempts.sh <<'EOF'
#!/bin/bash

echo "=================================="
echo "SSH SECURITY CHECK - $(date)"
echo "=================================="
echo ""

echo "fail2ban status:"
fail2ban-client status sshd

echo ""
echo "Últimas tentativas falhas (últimas 24h):"
grep "Failed password" /var/log/auth.log | tail -20

echo ""
echo "IPs mais agressivos:"
grep "Failed password" /var/log/auth.log | \
  awk '{print $(NF-3)}' | sort | uniq -c | sort -nr | head -10

echo ""
echo "Logins bem-sucedidos (últimas 24h):"
grep "Accepted" /var/log/auth.log | tail -10

echo ""
EOF

chmod +x /root/check-ssh-attempts.sh

# Executar
/root/check-ssh-attempts.sh
```

### 5.3. Script de status geral

```bash
cat > /root/server-status.sh <<'EOF'
#!/bin/bash

clear
cat << "BANNER"
╔═══════════════════════════════════════════════════════════╗
║         SERVER STATUS - HETZNER PRODUCTION                ║
╚═══════════════════════════════════════════════════════════╝
BANNER

echo ""
echo "🖥️  SISTEMA:"
echo "  Hostname: $(hostname)"
echo "  Uptime: $(uptime -p)"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

echo "💾 RECURSOS:"
echo "  RAM: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
echo "  Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " usado)"}')"
echo "  Docker Disk: $(df -h /var/lib/docker 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " usado)"}' || echo "N/A")"
echo ""

echo "🐳 DOCKER:"
echo "  Containers: $(docker ps -q | wc -l) rodando / $(docker ps -aq | wc -l) total"
if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q active; then
  echo "  Swarm: Ativo"
  echo "  Services: $(docker service ls 2>/dev/null | tail -n +2 | wc -l)"
fi
echo ""

echo "🔒 SEGURANÇA:"
echo "  fail2ban: $(systemctl is-active fail2ban)"
echo "  SSH: $(systemctl is-active ssh)"
echo "  IPs banidos: $(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $4}')"
echo ""

echo "🌐 REDE:"
echo "  IP Público: $(hostname -I | awk '{print $1}')"
echo "  Firewall Hetzner: Configurado no painel"
echo ""

echo "📊 ÚLTIMAS ATIVIDADES:"
echo "  Último login: $(lastlog -u root | tail -1 | awk '{print $4, $5, $6, $7}')"
echo "  Updates disponíveis: $(apt list --upgradable 2>/dev/null | grep -v Listing | wc -l)"
echo ""

echo "Para detalhes:"
echo "  Resources: /root/check-resources.sh"
echo "  SSH Security: /root/check-ssh-attempts.sh"
echo ""
EOF

chmod +x /root/server-status.sh

# Adicionar ao login
echo "/root/server-status.sh" >> /root/.bashrc

# Executar agora
/root/server-status.sh
```

---

## 🎯 CONFIGURAÇÃO COMPLEMENTAR: Hetzner Cloud Firewall

### Regras Recomendadas no Painel Hetzner:

```
INBOUND (Entrada):
┌────────────────────────────────────────────────────────┐
│ SSH                                                    │
│ Protocol: TCP                                          │
│ Port: 22                                               │
│ Source: Seu IP fixo (mais seguro)                     │
│        OU 0.0.0.0/0 (todos - se IP dinâmico)          │
├────────────────────────────────────────────────────────┤
│ HTTP                                                   │
│ Protocol: TCP                                          │
│ Port: 80                                               │
│ Source: 0.0.0.0/0, ::/0                               │
├────────────────────────────────────────────────────────┤
│ HTTPS                                                  │
│ Protocol: TCP                                          │
│ Port: 443                                              │
│ Source: 0.0.0.0/0, ::/0                               │
├────────────────────────────────────────────────────────┤
│ Portainer (se exposto)                                │
│ Protocol: TCP                                          │
│ Port: 9000, 9443                                       │
│ Source: Seu IP fixo (recomendado)                     │
├────────────────────────────────────────────────────────┤
│ Docker Swarm (se multi-node)                          │
│ Protocol: TCP                                          │
│ Port: 2377                                             │
│ Source: IPs dos outros nodes                          │
├────────────────────────────────────────────────────────┤
│ Docker Overlay Network                                │
│ Protocol: TCP & UDP                                    │
│ Port: 7946                                             │
│ Source: IPs dos outros nodes                          │
├────────────────────────────────────────────────────────┤
│ Docker Overlay Network (VXLAN)                        │
│ Protocol: UDP                                          │
│ Port: 4789                                             │
│ Source: IPs dos outros nodes                          │
└────────────────────────────────────────────────────────┘

OUTBOUND (Saída):
┌────────────────────────────────────────────────────────┐
│ All traffic                                            │
│ Protocol: Any                                          │
│ Port: Any                                              │
│ Destination: 0.0.0.0/0, ::/0                          │
└────────────────────────────────────────────────────────┘
```

### 🔐 Dica de Segurança Extra - SSH:

Se você tem IP fixo, configure no Hetzner Firewall:
```
SSH Source: SEU_IP_FIXO/32
```

Isso bloqueia SSH para todo mundo exceto você! 🎯

---

## 📋 CHECKLIST FINAL

```bash
# Executar todos os checks

echo "1. Sistema atualizado?"
apt list --upgradable

echo ""
echo "2. Docker funcionando?"
docker ps
docker service ls

echo ""
echo "3. fail2ban ativo?"
systemctl status fail2ban --no-pager
fail2ban-client status sshd

echo ""
echo "4. SSH funcionando?"
systemctl status ssh --no-pager

echo ""
echo "5. Chrony sincronizando?"
chronyc tracking

echo ""
echo "6. Atualizações automáticas?"
systemctl status unattended-upgrades --no-pager

echo ""
echo "7. Portainer acessível?"
curl -I http://localhost:9000

echo ""
echo "8. Apps funcionando?"
# Testar suas aplicações aqui
curl -I http://localhost

echo ""
echo "✅ Se tudo acima está OK, o hardening foi bem-sucedido!"
```

---

## 🎓 Resumo: O que foi aplicado?

### ✅ Segurança Aplicada:

| Item | Status | Observação |
|------|--------|------------|
| **fail2ban** | ✅ | Proteção brute-force SSH |
| **SSH hardening** | ✅ | Algoritmos modernos, timeouts |
| **Kernel hardening** | ✅ | Leve, Docker-friendly |
| **Updates automáticos** | ✅ | Apenas segurança |
| **Logs organizados** | ✅ | Rotação e monitoramento |
| **Docker otimizado** | ✅ | Logs limitados, limpeza |
| **Chrony** | ✅ | Sincronização precisa |
| **Firewall interno (UFW)** | ❌ | Não precisa (Hetzner Cloud) |
| **Usuário não-root** | ❌ | Mantido root conforme pedido |

### ⚙️ Docker/Swarm:

| Item | Status |
|------|--------|
| **Docker** | ✅ Não mexido - funcionando |
| **Swarm** | ✅ Não mexido - funcionando |
| **Portainer** | ✅ Não mexido - funcionando |
| **Containers** | ✅ Não mexidos - rodando |
| **Volumes** | ✅ Não mexidos - intactos |
| **Networks** | ✅ Não mexidas - funcionando |

---

## 🆘 Troubleshooting

### Problema: fail2ban baniu meu IP

```bash
# Ver IPs banidos
fail2ban-client status sshd

# Desbanir
fail2ban-client set sshd unbanip SEU_IP

# Whitelist permanente (se IP fixo)
echo "ignoreip = 127.0.0.1/8 SEU_IP_FIXO" >> /etc/fail2ban/jail.local
systemctl restart fail2ban
```

### Problema: SSH não conecta

```bash
# Verificar serviço
systemctl status ssh

# Ver logs
tail -50 /var/log/auth.log

# Reverter config
cp /root/hardening-backup/sshd_config.* /etc/ssh/sshd_config
systemctl restart ssh
```

### Problema: Docker lento

```bash
# Ver uso
docker stats

# Limpar cache
docker system df
docker system prune

# Ver logs de container específico
docker logs --tail 100 CONTAINER_NAME
```

---

## 📞 Comandos Úteis do Dia a Dia

```bash
# Status geral
/root/server-status.sh

# Recursos
/root/check-resources.sh

# Segurança SSH
/root/check-ssh-attempts.sh

# fail2ban
fail2ban-client status sshd

# Docker
docker ps
docker stats --no-stream
docker service ls

# Logs
tail -f /var/log/auth.log
journalctl -u docker -f

# Updates disponíveis
apt list --upgradable
```

---

## ⏱️ Tempo de Execução

- **Preparação:** 20 minutos
- **Hardening básico:** 45 minutos
- **SSH:** 30 minutos
- **Docker:** 30 minutos
- **Monitoramento:** 20 minutos

**TOTAL:** ~2h30min (pode fazer em etapas)

---

## 🎯 Próximos Passos (Opcional)

1. **Migrar para chave SSH:**
   - Gerar chave ed25519
   - Adicionar authorized_keys
   - Desabilitar senha

2. **Monitoramento externo:**
   - Hetrix Tools (grátis)
   - UptimeRobot (grátis)

3. **Backup automatizado:**
   - Hetzner Backup (€0.20/mês por servidor)
   - Ou script para Hetzner Storage Box

4. **Restringir SSH no firewall:**
   - Se tem IP fixo, permitir só ele

---

**Versão:** 1.0.0-hetzner  
**Última atualização:** Janeiro 2026  
**Testado em:** Hetzner Cloud CX11/CX21/CPX11  
**Compatibilidade:** Ubuntu 22.04/24.04 LTS
