# Guia de Hardening para VPS em Produção
## Migração Segura sem Downtime

> ⚠️ **ATENÇÃO:** Este guia é para VPS **JÁ EM PRODUÇÃO** com Docker Swarm + Portainer
> 
> **Objetivo:** Aplicar segurança SEM derrubar aplicações

---

## 🎯 Estratégia

### Princípios:
1. ✅ **Não mexer** no Docker/Swarm/Portainer existente
2. ✅ **Testar tudo** antes de aplicar definitivamente
3. ✅ **Backup** antes de cada mudança
4. ✅ **Rollback** fácil se algo der errado
5. ✅ **Zero downtime** nas aplicações

### Ordem de Execução:
1. Análise e backup (30 min)
2. Hardening básico (1h) - **SEM RISCO**
3. Hardening SSH (30 min) - **CUIDADO**
4. Hardening avançado (1h) - **OPCIONAL**

---

## 📋 FASE 1: Preparação e Backup (30 minutos)

### 1.1. Criar snapshot da VPS

**No painel da sua VPS (DigitalOcean, Linode, etc):**
- Criar snapshot/backup completo
- Anotar o ID do snapshot
- **NÃO PULE ESTE PASSO!**

### 1.2. Documentar estado atual

```bash
# Conectar como root
ssh root@sua-vps

# Criar diretório para backups
mkdir -p /root/migration-backup
cd /root/migration-backup

# Documentar configuração atual
cat > current-state.txt <<EOF
Data: $(date)
Hostname: $(hostname)
IP: $(hostname -I)
OS: $(lsb_release -ds)
Kernel: $(uname -r)
RAM: $(free -h | grep Mem | awk '{print $2}')
Disk: $(df -h / | awk 'NR==2{print $4}') livre
Docker: $(docker --version)
Swarm: $(docker info --format '{{.Swarm.LocalNodeState}}')
Containers: $(docker ps --format "{{.Names}}" | wc -l) rodando
EOF

# Ver containers rodando
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Salvar lista completa
docker ps -a > containers-list.txt
docker images > images-list.txt
docker network ls > networks-list.txt
docker volume ls > volumes-list.txt

# Se for Swarm
docker stack ls > stacks-list.txt 2>/dev/null || true
docker service ls > services-list.txt 2>/dev/null || true

# Backup configs importantes
cp -r /etc/ssh /root/migration-backup/ssh-backup
cp -r /etc/docker /root/migration-backup/docker-backup

# Se tiver Portainer
docker inspect portainer > portainer-config.json 2>/dev/null || true

# Ver portas abertas
ss -tulpn > ports-open.txt

cat current-state.txt
```

### 1.3. Identificar riscos

```bash
# Verificar se root está sendo usado pelos containers
docker ps --format "{{.Names}}" | while read container; do
  echo "Container: $container"
  docker inspect $container | grep -i "user" | head -5
  echo "---"
done > containers-users.txt

# Ver volumes montados
docker ps --format "{{.Names}}" | while read container; do
  echo "Container: $container"
  docker inspect $container | grep -A5 "Mounts"
  echo "---"
done > containers-mounts.txt

cat current-state.txt
```

**📝 Anote:**
- Quantos containers estão rodando?
- Quais portas estão expostas?
- Portainer está em qual porta?
- Algum container usa volumes em `/root`?

---

## 🔒 FASE 2: Hardening Básico - ZERO RISCO (1 hora)

### 2.1. Atualizações de segurança

```bash
# Atualizar sistema (Docker continuará rodando)
apt-get update
apt-get upgrade -y

# Docker e containers NÃO serão afetados
```

### 2.2. Instalar ferramentas de segurança

```bash
# Instalar pacotes sem afetar Docker
apt-get install -y \
  ufw \
  fail2ban \
  unattended-upgrades \
  chrony \
  logwatch

# Nada será configurado ainda - só instalado
```

### 2.3. Configurar fail2ban (proteção SSH)

```bash
# Backup da config
cp /etc/fail2ban/jail.conf /root/migration-backup/

# Configurar fail2ban
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

# Iniciar fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# Verificar
fail2ban-client status sshd
```

**✅ Resultado:** Proteção contra brute-force SSH ativada (Docker não afetado)

### 2.4. Hardening de kernel (LEVE)

```bash
# Backup
cp /etc/sysctl.conf /root/migration-backup/

# Aplicar hardening leve
cat >> /etc/sysctl.d/99-hardening-production.conf <<'EOF'
# Proteção básica
fs.protected_hardlinks=1
fs.protected_symlinks=1

# Network (mantém Docker funcionando)
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1

# IMPORTANTE: log_martians=0 (Docker)
net.ipv4.conf.all.log_martians=0
net.ipv4.conf.default.log_martians=0
EOF

# Aplicar
sysctl --system

# Verificar Docker ainda funciona
docker ps
```

**✅ Resultado:** Kernel protegido (Docker continua funcionando)

### 2.5. Atualizações automáticas

```bash
# Configurar updates automáticos
cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

dpkg-reconfigure -f noninteractive unattended-upgrades
```

**✅ Resultado:** Sistema se atualiza automaticamente (sem reiniciar)

### 2.6. Monitoramento de logs

```bash
# Configurar logwatch
cat > /etc/cron.weekly/00logwatch <<'EOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail low
EOF
chmod +x /etc/cron.weekly/00logwatch
```

**✅ CHECKPOINT 1:** Docker ainda está funcionando?

```bash
docker ps
docker service ls  # Se for Swarm
curl http://localhost:9000  # Portainer (ajuste a porta)
```

Se tudo OK, continuar ✅

---

## 🔐 FASE 3: Hardening SSH - CUIDADO! (30 minutos)

> ⚠️ **CRÍTICO:** Esta fase pode te trancar fora se não tomar cuidado!

### 3.1. Criar usuário não-root

```bash
# Criar usuário para administração
adduser admin  # Use um nome diferente se preferir
# Defina uma SENHA FORTE

# Adicionar ao grupo sudo
usermod -aG sudo admin

# Adicionar ao grupo docker
usermod -aG docker admin

# Configurar SSH para o novo usuário
mkdir -p /home/admin/.ssh
chmod 700 /home/admin/.ssh

# Copiar chaves SSH (se você usa)
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/admin/.ssh/authorized_keys
  chmod 600 /home/admin/.ssh/authorized_keys
  chown -R admin:admin /home/admin/.ssh
fi
```

### 3.2. TESTAR novo usuário

```bash
# ABRIR OUTRA JANELA/TERMINAL
# Testar conexão com novo usuário
ssh admin@sua-vps

# Se conectou, testar sudo
sudo docker ps

# Testar Portainer
sudo docker exec -it portainer ls  # ou nome do seu container

# Se tudo funcionou, voltar para a janela root
```

**⚠️ SÓ CONTINUE SE O TESTE ACIMA FUNCIONOU!**

### 3.3. Endurecer SSH (GRADUALMENTE)

```bash
# Backup SSH config
cp /etc/ssh/sshd_config /root/migration-backup/sshd_config.backup

# PASSO 1: Configuração moderada (permite senha ainda)
mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-hardening-production.conf <<'EOF'
# Autenticação (PERMITE SENHA por enquanto)
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes  # Ainda permite root
PermitEmptyPasswords no

# Segurança
MaxAuthTries 5  # Mais permissivo que 3
MaxSessions 10
LoginGraceTime 60

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
LogLevel VERBOSE
EOF

# Testar configuração
sshd -t

# Se OK, recarregar
systemctl reload ssh
```

### 3.4. TESTAR SSH novamente

```bash
# Em OUTRA JANELA
ssh admin@sua-vps
ssh root@sua-vps

# Ambos devem funcionar
```

### 3.5. Desabilitar root SSH (GRADUALMENTE)

**⚠️ SÓ FAÇA DEPOIS DE CONFIRMAR QUE `admin` FUNCIONA!**

```bash
# Editar SSH config
nano /etc/ssh/sshd_config.d/99-hardening-production.conf

# Mudar linha:
# PermitRootLogin yes  →  PermitRootLogin prohibit-password

# Salvar (Ctrl+O, Enter, Ctrl+X)

# Testar
sshd -t

# Recarregar
systemctl reload ssh
```

**🧪 TESTAR:**
```bash
# Tentar logar como root COM SENHA (deve falhar)
ssh root@sua-vps
# Deve dar: Permission denied

# Logar como admin (deve funcionar)
ssh admin@sua-vps
# Deve funcionar

# Sudo como admin (deve funcionar)
ssh admin@sua-vps
sudo docker ps
# Deve funcionar
```

**✅ CHECKPOINT 2:** Você consegue logar como `admin` e usar docker?

---

## 🔥 FASE 4: Firewall - MUITO CUIDADO! (30 minutos)

> ⚠️ **PERIGO:** Firewall pode bloquear Portainer/aplicações!

### 4.1. Identificar portas necessárias

```bash
# Ver portas em uso
ss -tulpn | grep LISTEN > /root/migration-backup/ports-before-firewall.txt
cat /root/migration-backup/ports-before-firewall.txt

# Identificar:
# - Porta SSH (22?)
# - Porta Portainer (9000? 9443?)
# - Portas das aplicações (80? 443? outras?)
# - Portas Swarm (2377, 7946, 4789)
```

**📝 ANOTE TODAS AS PORTAS QUE PRECISAM FICAR ABERTAS!**

### 4.2. Configurar UFW (SEM HABILITAR ainda)

```bash
# Reset UFW (ainda desabilitado)
ufw --force reset

# Defaults
ufw default deny incoming
ufw default allow outgoing

# SSH (CRÍTICO!)
ufw allow 22/tcp

# Portainer (ajuste a porta se diferente)
ufw allow 9000/tcp
ufw allow 9443/tcp

# HTTP/HTTPS (se suas apps usam)
ufw allow 80/tcp
ufw allow 443/tcp

# Docker Swarm (se você usa)
ufw allow 2377/tcp  # Cluster management
ufw allow 7946/tcp  # Container network discovery
ufw allow 7946/udp
ufw allow 4789/udp  # Overlay network

# Outras portas específicas das suas apps
# ufw allow PORTA/tcp

# Ver regras configuradas (mas não ativas ainda)
ufw show added
```

### 4.3. Integração UFW + Docker

```bash
# IMPORTANTE: UFW pode quebrar Docker se não configurar direito

# Backup
cp /etc/ufw/after.rules /root/migration-backup/

# Adicionar regras Docker
cat >> /etc/ufw/after.rules <<'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]

# Permitir redes Docker
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

# Encaminhar para UFW
-A DOCKER-USER -j ufw-user-forward

# Drop inválidos
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -j RETURN

COMMIT
# END UFW AND DOCKER
EOF
```

### 4.4. TESTAR firewall (modo dry-run)

```bash
# Verificar regras
ufw show added

# Conferir se SSH está permitido
ufw status numbered | grep 22

# IMPORTANTE: Verificar se tem DUAS janelas SSH abertas
# Janela 1: root/admin conectado
# Janela 2: pronta para testar
```

### 4.5. Habilitar UFW (MOMENTO CRÍTICO!)

```bash
# ⚠️ CERTIFIQUE-SE DE TER 2 JANELAS SSH ABERTAS!

# Habilitar
ufw --force enable

# IMEDIATAMENTE testar na Janela 2
# ssh admin@sua-vps

# Se FUNCIONOU:
echo "✅ SSH funcionando com firewall!"

# Testar aplicações
curl http://localhost:9000  # Portainer
docker ps
docker service ls

# Testar de fora
curl http://seu-ip-publico  # Suas apps
```

**🆘 Se TRAVAR:**
```bash
# Na janela que ainda está conectada:
ufw disable

# Revisar regras
ufw status numbered

# Adicionar porta que faltou
ufw allow PORTA/tcp

# Tentar de novo
ufw enable
```

**✅ CHECKPOINT 3:** Firewall ativo e tudo funcionando?

---

## 🎯 FASE 5: Otimizações Finais (30 minutos)

### 5.1. Limitar recursos Docker

```bash
# Configurar limpeza automática
cat > /etc/cron.weekly/docker-cleanup-production <<'EOF'
#!/bin/bash
# Limpeza CONSERVADORA (não remove imagens em uso)

# Remover containers parados há mais de 30 dias
docker container prune -f --filter "until=720h"

# Remover imagens não usadas há mais de 30 dias
docker image prune -af --filter "until=720h"

# Logs antigos
find /var/log -type f -name "*.gz" -mtime +60 -delete

# APT
apt-get clean
EOF

chmod +x /etc/cron.weekly/docker-cleanup-production
```

### 5.2. Configurar limites de logs Docker

```bash
# Editar daemon.json (CUIDADO: pode afetar containers)
cp /etc/docker/daemon.json /root/migration-backup/ 2>/dev/null || true

# Verificar config atual
cat /etc/docker/daemon.json 2>/dev/null || echo "{}"

# Adicionar limitação de logs (NÃO afeta containers existentes)
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF

# Recarregar daemon (NÃO reinicia containers)
systemctl daemon-reload

# Verificar
docker info | grep -i logging
```

**📝 Nota:** Containers existentes continuam com config antiga. Só novos containers usarão a nova config.

### 5.3. Permissões críticas

```bash
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 644 /etc/group
chmod 640 /etc/gshadow
```

### 5.4. Criar script de verificação

```bash
cat > /root/check-security.sh <<'EOF'
#!/bin/bash

echo "=========================================="
echo "SECURITY STATUS CHECK"
echo "=========================================="
echo ""

echo "Docker:"
docker ps -q | wc -l | xargs echo "  Containers rodando:"
docker service ls --format "{{.Name}}" 2>/dev/null | wc -l | xargs echo "  Services rodando:" || echo "  Services: N/A"
echo ""

echo "Firewall:"
ufw status | head -3
echo ""

echo "fail2ban:"
fail2ban-client status sshd | grep "Currently banned"
echo ""

echo "SSH:"
grep "^PermitRootLogin" /etc/ssh/sshd_config.d/*.conf 2>/dev/null || echo "  Root login: enabled"
echo ""

echo "Últimos logins:"
lastlog | head -10
echo ""

echo "Disk usage:"
df -h / | tail -1
echo ""

echo "Memory:"
free -h | grep Mem
echo ""

echo "Processos:"
ps aux | wc -l | xargs echo "  Total:"
echo ""
EOF

chmod +x /root/check-security.sh

# Executar
/root/check-security.sh
```

---

## 📊 CHECKLIST FINAL

```bash
# Executar e verificar TUDO

# 1. Docker funcionando?
docker ps
docker service ls

# 2. Portainer funcionando?
curl -I http://localhost:9000

# 3. Apps funcionando?
curl -I http://seu-dominio.com

# 4. SSH funcionando com usuário admin?
ssh admin@sua-vps "docker ps"

# 5. Firewall ativo?
ufw status

# 6. fail2ban ativo?
fail2ban-client status sshd

# 7. Logs sendo monitorados?
tail -20 /var/log/auth.log

# 8. Atualizações automáticas?
systemctl status unattended-upgrades
```

---

## 🎓 Resumo do que foi feito

### ✅ Aplicado (SEM RISCO):
- Updates automáticos de segurança
- fail2ban protegendo SSH
- Kernel hardening leve
- Logs organizados
- Limpeza automática

### ✅ Aplicado (COM CUIDADO):
- Usuário não-root criado
- SSH endurecido
- Root SSH desabilitado (ou restrito)
- Firewall ativo
- Docker integrado ao firewall

### ❌ NÃO Aplicado (NÃO MEXEMOS):
- Docker Swarm (mantido intacto)
- Portainer (mantido intacto)
- Containers existentes (mantidos intactos)
- Volumes (mantidos intactos)
- Networks (mantidas intactas)

---

## 🆘 Plano de Rollback

Se algo der errado:

### Opção 1: Reverter configurações

```bash
# SSH
cp /root/migration-backup/sshd_config.backup /etc/ssh/sshd_config
systemctl restart ssh

# Firewall
ufw disable

# Docker
cp /root/migration-backup/docker-backup/daemon.json /etc/docker/
systemctl restart docker

# Kernel
cp /root/migration-backup/sysctl.conf /etc/sysctl.conf
sysctl --system
```

### Opção 2: Restaurar snapshot

- Ir no painel da VPS
- Restaurar snapshot criado no início
- Perderá mudanças feitas APÓS o snapshot

---

## 📈 Próximos Passos (Opcional)

### Depois de tudo estável:

1. **Migrar para chave SSH:**
   ```bash
   # Desabilitar senha completamente
   # PasswordAuthentication no
   ```

2. **Monitoramento externo:**
   - UptimeRobot
   - Hetrixtools
   - Datadog

3. **Backup automatizado:**
   - Backups diários automáticos
   - Testar restauração

4. **AppArmor/SELinux:**
   - Para proteção avançada

---

## ⚠️ REGRAS DE OURO

1. **SEMPRE ter 2 janelas SSH abertas**
2. **SEMPRE fazer backup antes de mudar**
3. **SEMPRE testar antes de aplicar**
4. **NUNCA mexer em Docker/Swarm em produção**
5. **NUNCA habilitar firewall sem testar**

---

## 📞 Troubleshooting

### Problema: Me tranquei fora!

**Solução:**
- Console VNC do painel da VPS
- Ou restaurar snapshot

### Problema: Docker parou de funcionar

**Solução:**
```bash
# Desabilitar firewall temporariamente
ufw disable

# Verificar Docker
systemctl status docker
journalctl -u docker -n 50

# Restaurar config
cp /root/migration-backup/docker-backup/daemon.json /etc/docker/
systemctl restart docker
```

### Problema: Portainer inacessível

**Solução:**
```bash
# Verificar se está rodando
docker ps | grep portainer

# Verificar firewall
ufw status | grep 9000

# Adicionar porta se necessário
ufw allow 9000/tcp
```

---

**Tempo total estimado:** 2-3 horas  
**Risco de downtime:** Mínimo (se seguir o guia)  
**Reversibilidade:** 100% (com snapshot)

**Última atualização:** Janeiro 2026  
**Testado em:** Ubuntu 22.04 LTS com Docker Swarm
