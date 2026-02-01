#!/bin/bash

# VPS Hardening Script - Versão Revisada (Dev/Test)
# Para Ubuntu 22.04+ | VPS Compartilhada (2 vCPU / 2-4GB RAM)
# AVISO: Configuração com sudo sem senha + root com senha (apenas dev/test)

set -euo pipefail
IFS=$'\n\t'

# =========================
# Configurações
# =========================
MIN_UBUNTU_VERSION="22.04"
MIN_RAM_MB=900
MIN_DISK_GB=5

# =========================
# UI
# =========================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${YELLOW}▶ $1${NC}"; }
ok()  { echo -e "${GREEN}✔ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }
warn() { echo -e "${RED}⚠ $1${NC}"; }
die() { echo -e "${RED}✖ $1${NC}"; exit 1; }

trap 'die "Erro na linha $LINENO"' ERR

# =========================
# Banner
# =========================
clear
cat << "EOF"
╔═══════════════════════════════════════════════╗
║   VPS Hardening - Dev/Test Edition           ║
║   Configuração flexível para desenvolvimento  ║
╚═══════════════════════════════════════════════╝
EOF
echo ""

# =========================
# AVISOS DE SEGURANÇA
# =========================
warn "═══════════════════════════════════════════════"
warn "  ATENÇÃO: CONFIGURAÇÃO PARA DEV/TEST APENAS"
warn "═══════════════════════════════════════════════"
echo ""
warn "Esta configuração inclui:"
warn "  • Root login com SENHA habilitado"
warn "  • Usuário 'docker' com sudo (requer senha)"
warn "  • Autenticação por senha habilitada"
echo ""
warn "❌ NÃO USE EM PRODUÇÃO!"
warn "✓  OK para desenvolvimento/teste com fail2ban"
echo ""
read -p "Você entende os riscos e deseja continuar? (digite 'sim'): " CONFIRM
[[ "$CONFIRM" != "sim" ]] && die "Instalação cancelada"
echo ""

# =========================
# Pré-checks
# =========================
log "Validando ambiente..."

[[ $EUID -eq 0 ]] || die "Execute como root (sudo su -)"

command -v lsb_release >/dev/null || die "lsb_release não encontrado"

UBUNTU_VERSION=$(lsb_release -rs)
dpkg --compare-versions "$UBUNTU_VERSION" ge "$MIN_UBUNTU_VERSION" \
  || die "Ubuntu $MIN_UBUNTU_VERSION ou superior necessário (atual: $UBUNTU_VERSION)"

RAM=$(free -m | awk '/^Mem:/{print $2}')
DISK=$(df -BG / | awk 'NR==2{gsub("G","");print $4}')

(( RAM >= MIN_RAM_MB )) || die "RAM insuficiente: ${RAM}MB (mínimo: ${MIN_RAM_MB}MB)"
(( DISK >= MIN_DISK_GB )) || die "Disco insuficiente: ${DISK}GB (mínimo: ${MIN_DISK_GB}GB)"

ok "Sistema compatível: Ubuntu $UBUNTU_VERSION | ${RAM}MB RAM | ${DISK}GB disco livre"
echo ""

# =========================
# Atualização do sistema
# =========================
log "Atualizando sistema (pode demorar alguns minutos)..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# =========================
# Pacotes essenciais (otimizados para 2GB RAM)
# =========================
log "Instalando pacotes de segurança..."
apt-get install -y -qq \
  ufw \
  fail2ban \
  curl \
  wget \
  unattended-upgrades \
  apparmor \
  apparmor-utils \
  chrony \
  logwatch \
  apt-listchanges \
  vim \
  htop \
  ncdu \
  net-tools

ok "Pacotes instalados"

# =========================
# Sincronização de tempo
# =========================
log "Configurando sincronização de tempo (chrony)..."
systemctl disable systemd-timesyncd --now 2>/dev/null || true

cat >/etc/chrony/chrony.conf <<'EOF'
# Servidores NTP otimizados para América do Sul
pool 2.south-america.pool.ntp.org iburst maxsources 2
pool 2.ubuntu.pool.ntp.org iburst maxsources 1

driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync

# Logging leve
logdir /var/log/chrony
EOF

systemctl enable chrony --now
sleep 2

if chronyc tracking &>/dev/null; then
  ok "Chrony sincronizando"
else
  warn "Chrony pode não estar sincronizando (normal em VPS)"
fi

# =========================
# Hardening de Kernel (LEVE - otimizado para 2GB RAM)
# =========================
log "Aplicando hardening de kernel (otimizado para VPS pequena)..."
cat >/etc/sysctl.d/99-hardening-vps.conf <<'EOF'
# ========================================
# Hardening para VPS Compartilhada (2GB)
# ========================================

# Proteção de filesystem
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0

# Limites ajustados para 2GB RAM
fs.file-max = 262144
kernel.pid_max = 32768

# Rede - Compatível com Docker
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Proteções de rede
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Desabilita log_martians (evita spam com Docker)
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.default.log_martians = 0

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 2048

# ICMP
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# IPv6 (desabilitar se não usar)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# TCP otimizações leves
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Memória (conservador para 2GB)
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# OOM killer menos agressivo
vm.overcommit_memory = 1
vm.panic_on_oom = 0
EOF

sysctl --system >/dev/null
ok "Parâmetros de kernel aplicados"

# =========================
# SWAP (se não existir e houver espaço)
# =========================
if [ ! -f /swapfile ] && [ "$DISK" -gt 10 ]; then
  log "Criando arquivo swap de 2GB..."
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
  ok "Swap criado e ativado"
else
  info "Swap já existe ou disco insuficiente"
fi

# =========================
# AppArmor
# =========================
log "Ativando AppArmor..."
systemctl enable apparmor --now
aa-enforce /etc/apparmor.d/usr.sbin.tcpdump 2>/dev/null || true
ok "AppArmor ativo"

# =========================
# Docker (instalação otimizada)
# =========================
log "Instalando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  ok "Docker instalado"
else
  ok "Docker já instalado"
fi

systemctl enable docker --now

log "Configurando Docker (otimizado para 2GB RAM)..."
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",
    "max-file": "2"
  },
  "userland-proxy": false,
  "no-new-privileges": true,
  "iptables": true,
  "storage-driver": "overlay2",
  "live-restore": true,
  "features": {
    "buildkit": true
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 4096,
      "Soft": 2048
    }
  }
}
EOF

systemctl daemon-reload
systemctl restart docker

sleep 3
if docker info &>/dev/null; then
  ok "Docker configurado e funcionando"
else
  die "Docker não está respondendo"
fi

# =========================
# Usuário docker com sudo SEM senha
# =========================
# Usuário docker
# =========================
log "Configurando usuário docker..."

# Verificar se usuário docker já existe
if id docker &>/dev/null 2>&1; then
  log "Usuário docker já existe, configurando grupos..."
  usermod -aG docker,sudo docker || {
    warn "Aviso: Não foi possível adicionar aos grupos, tentando alternativa..."
    # Remover e recriar se houver problema
    userdel -r docker 2>/dev/null || true
    sleep 1
  }
fi

# Se ainda não existe, criar
if ! id docker &>/dev/null 2>&1; then
  log "Criando usuário docker..."
  
  # Criar usuário com seu próprio grupo primário
  if useradd -m -s /bin/bash docker; then
    ok "Usuário docker criado"
  else
    die "Falha ao criar usuário docker"
  fi
  
  # Adicionar aos grupos necessários
  if usermod -aG docker,sudo docker; then
    ok "Usuário docker adicionado aos grupos: docker, sudo"
  else
    die "Falha ao adicionar usuário aos grupos"
  fi
else
  ok "Usuário docker configurado nos grupos: docker, sudo"
fi

# Verificar configuração final
DOCKER_GROUPS=$(groups docker 2>/dev/null | cut -d: -f2 || echo "erro")
if [[ "$DOCKER_GROUPS" == *"docker"* ]] && [[ "$DOCKER_GROUPS" == *"sudo"* ]]; then
  ok "Grupos do usuário docker confirmados: $DOCKER_GROUPS"
else
  warn "Aviso: Grupos podem não estar corretos: $DOCKER_GROUPS"
fi

# =========================
# Configuração de sudo (COM senha)
# =========================
# Usuário docker está no grupo 'sudo', que por padrão requer senha
# Não é necessário criar arquivo em /etc/sudoers.d/
# O comportamento padrão do Ubuntu já é adequado
log "Configuração de sudo: usuário docker requer senha (padrão do grupo sudo)"

# Remover arquivo NOPASSWD se existir (de versões antigas do script)
if [ -f /etc/sudoers.d/docker ]; then
  rm -f /etc/sudoers.d/docker
  ok "Arquivo /etc/sudoers.d/docker removido (não necessário)"
fi

# =========================
# Setup SSH directory para usuário docker
# =========================
mkdir -p /home/docker/.ssh
chmod 700 /home/docker/.ssh
touch /home/docker/.ssh/authorized_keys
chmod 600 /home/docker/.ssh/authorized_keys
chown -R docker:docker /home/docker

# Copiar chaves SSH se existirem
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/docker/.ssh/authorized_keys
  chmod 600 /home/docker/.ssh/authorized_keys
  chown docker:docker /home/docker/.ssh/authorized_keys
  ok "Chaves SSH copiadas para usuário docker"
fi

# =========================
# SSH Hardening (COM SENHA para root e docker)
# =========================
log "Configurando SSH (senha habilitada para root e docker)..."

# Backup
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)

mkdir -p /etc/ssh/sshd_config.d

cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
# ============================================
# SSH Hardening - Dev/Test (Senha habilitada)
# ============================================

# Autenticação - PERMITE SENHA (com limitações)
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes
ChallengeResponseAuthentication no
PermitEmptyPasswords no

# Segurança extra
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30
MaxStartups 3:50:10

# Recursos
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding no
PermitTunnel no

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Usuários permitidos
AllowUsers docker root

# Logging detalhado (importante com senha habilitada)
LogLevel VERBOSE
SyslogFacility AUTH

# Algoritmos seguros modernos
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,rsa-sha2-512,rsa-sha2-256

# Banner de aviso
Banner /etc/ssh/banner
EOF

# Criar banner
cat >/etc/ssh/banner <<'EOF'
***************************************************************************
                    ACESSO RESTRITO - AMBIENTE DE TESTE
***************************************************************************
Este sistema está protegido por fail2ban. Tentativas de login mal-sucedidas
serão banidas automaticamente.

Uso autorizado apenas.
***************************************************************************
EOF

# Testar configuração
if sshd -t 2>/dev/null; then
  systemctl reload ssh
  ok "SSH configurado (SENHA HABILITADA para root e docker)"
else
  die "Configuração SSH inválida!"
fi

# =========================
# Firewall (UFW + Docker)
# =========================
log "Configurando firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Limitar conexões SSH (proteção extra)
ufw limit OpenSSH comment 'SSH rate limiting'

# Portas comuns para desenvolvimento (comente as que não usar)
# ufw allow 80/tcp comment 'HTTP'
# ufw allow 443/tcp comment 'HTTPS'
# ufw allow 3000/tcp comment 'Node.js dev'
# ufw allow 8080/tcp comment 'Alt HTTP'

# Integração UFW + Docker
mkdir -p /etc/ufw
cat >>/etc/ufw/after.rules <<'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]

# Permite redes privadas Docker
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

# Encaminha para regras UFW
-A DOCKER-USER -j ufw-user-forward

# Drop pacotes inválidos
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP

# Return se passou pelas regras
-A DOCKER-USER -j RETURN

COMMIT
# END UFW AND DOCKER
EOF

ufw --force enable
ok "Firewall ativo com rate limiting"

# =========================
# fail2ban (CRÍTICO - configuração agressiva)
# =========================
log "Configurando fail2ban (proteção essencial)..."

cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# Configuração AGRESSIVA devido a senha habilitada
bantime = 1h
findtime = 10m
maxretry = 3
destemail = root@localhost
sender = fail2ban@localhost
action = %(action_mwl)s

# Ignorar IPs locais
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
findtime = 10m

# Proteção contra scans
[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 6
bantime = 30m
findtime = 5m

# Proteção contra brute-force agressivo
[sshd-aggressive]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 24h
findtime = 1h
EOF

# Filtro DDOS customizado
cat >/etc/fail2ban/filter.d/sshd-ddos.conf <<'EOF'
[Definition]
failregex = ^%(__prefix_line)sDid not receive identification string from <HOST>\s*$
            ^%(__prefix_line)sConnection (closed|reset) by (<HOST>|authenticating user \S+) <HOST> port \d+\s*(\[preauth\])?\s*$
            ^%(__prefix_line)sConnection (closed|reset) by invalid user \S+ <HOST> port \d+\s*(\[preauth\])?\s*$
ignoreregex =
EOF

systemctl enable fail2ban --now
sleep 2

ok "fail2ban ativo (proteção agressiva contra brute-force)"

# =========================
# Limites de recursos (ajustados para 2GB)
# =========================
log "Configurando limites de recursos..."
cat >/etc/security/limits.d/vps.conf <<'EOF'
# Limites para VPS 2GB RAM
* soft nofile 4096
* hard nofile 8192
* soft nproc 2048
* hard nproc 4096
* soft memlock 256
* hard memlock 256
EOF

ok "Limites configurados"

# =========================
# Limpeza automática Docker + Sistema
# =========================
log "Configurando limpeza automática..."

cat >/etc/cron.daily/docker-cleanup <<'EOF'
#!/bin/bash
# Limpeza diária leve

# Docker - remove apenas stopped containers e dangling images
docker container prune -f --filter "until=24h" >/dev/null 2>&1 || true
docker image prune -f --filter "dangling=true" >/dev/null 2>&1 || true

# Logs do sistema (mantém últimos 7 dias)
find /var/log -type f -name "*.gz" -mtime +7 -delete 2>/dev/null || true
find /var/log -type f -name "*.1" -mtime +3 -delete 2>/dev/null || true

# Journal logs (limita a 100MB)
journalctl --vacuum-size=100M >/dev/null 2>&1 || true

# APT cache
apt-get clean 2>/dev/null || true
EOF

chmod +x /etc/cron.daily/docker-cleanup

# Limpeza semanal mais profunda
cat >/etc/cron.weekly/docker-cleanup-deep <<'EOF'
#!/bin/bash
# Limpeza semanal profunda

# Docker - limpeza completa (mantém últimas 168h = 7 dias)
docker system prune -af --volumes --filter "until=168h" >/dev/null 2>&1 || true

# Remove kernels antigos (mantém atual e anterior)
apt-get autoremove --purge -y >/dev/null 2>&1 || true

# Limpa arquivos temporários antigos
find /tmp -type f -atime +7 -delete 2>/dev/null || true
find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
EOF

chmod +x /etc/cron.weekly/docker-cleanup-deep

ok "Cron de limpeza configurado (diário + semanal)"

# =========================
# Atualizações automáticas
# =========================
log "Configurando atualizações automáticas de segurança..."
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";

Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";

Dpkg::Options {
    "--force-confdef";
    "--force-confold";
};
EOF

cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

dpkg-reconfigure -f noninteractive unattended-upgrades
ok "Atualizações automáticas ativas"

# =========================
# Permissões críticas
# =========================
log "Ajustando permissões de arquivos críticos..."
chmod 644 /etc/passwd
chmod 640 /etc/shadow
chmod 644 /etc/group
chmod 640 /etc/gshadow
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
ok "Permissões ajustadas"

# =========================
# Logwatch (relatórios semanais)
# =========================
log "Configurando logwatch..."
cat >/etc/cron.weekly/00logwatch <<'EOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail low --range 'between -7 days and today'
EOF
chmod +x /etc/cron.weekly/00logwatch
ok "Logwatch configurado"

# =========================
# Script de monitoramento
# =========================
log "Criando scripts de monitoramento..."

cat >/usr/local/bin/vps-status <<'EOF'
#!/bin/bash
# Script de status da VPS

echo "======================================"
echo "VPS Status Report"
echo "Date: $(date)"
echo "======================================"
echo ""

echo "SYSTEM:"
echo "  Uptime: $(uptime -p)"
echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "  RAM: $(free -h | awk '/^Mem:/{printf "%s / %s (%.0f%%)", $3, $2, ($3/$2)*100}')"
echo "  Disk: $(df -h / | awk 'NR==2{printf "%s / %s (%s)", $3, $2, $5}')"
echo ""

echo "DOCKER:"
echo "  Containers running: $(docker ps -q | wc -l)"
echo "  Images: $(docker images -q | wc -l)"
echo "  Disk usage: $(docker system df | awk 'NR==2{print $3}')"
echo ""

echo "SECURITY:"
echo "  UFW status: $(ufw status | grep Status | awk '{print $2}')"
echo "  fail2ban status: $(systemctl is-active fail2ban)"
echo "  Banned IPs (SSH): $(fail2ban-client status sshd 2>/dev/null | grep 'Currently banned' | awk '{print $4}')"
echo ""

echo "RECENT LOGIN ATTEMPTS (last 20):"
tail -n 20 /var/log/auth.log | grep -i 'failed\|accepted' | tail -10
echo ""

echo "TOP 5 PROCESSES BY MEMORY:"
ps aux --sort=-%mem | head -6
echo ""
EOF

chmod +x /usr/local/bin/vps-status

cat >/usr/local/bin/fail2ban-status <<'EOF'
#!/bin/bash
# Status do fail2ban

echo "======================================"
echo "fail2ban Status"
echo "======================================"
echo ""

fail2ban-client status

echo ""
echo "Banned IPs in sshd:"
fail2ban-client status sshd

echo ""
echo "Recent bans:"
grep "Ban " /var/log/fail2ban.log | tail -20
EOF

chmod +x /usr/local/bin/fail2ban-status

ok "Scripts de monitoramento criados (/usr/local/bin/vps-status e fail2ban-status)"

# =========================
# Limpeza final
# =========================
apt-get autoremove -y -qq
apt-get clean

# =========================
# Relatório de instalação
# =========================
clear
cat << "EOF"
╔═══════════════════════════════════════════════╗
║        INSTALAÇÃO CONCLUÍDA COM SUCESSO!      ║
╚═══════════════════════════════════════════════╝
EOF
echo ""

cat > /root/hardening-report.txt <<REPORT
================================================
RELATÓRIO DE HARDENING - VPS DEV/TEST
Data: $(date)
Hostname: $(hostname)
IP: $(hostname -I | awk '{print $1}')
================================================

SISTEMA:
- OS: Ubuntu $UBUNTU_VERSION
- RAM: ${RAM}MB
- Disco livre: ${DISK}GB
- Swap: $(swapon --show | tail -1 | awk '{print $3}' || echo "N/A")
- Uptime: $(uptime -p)
- Docker: $(docker --version 2>/dev/null || echo "Não instalado")

SERVIÇOS DE SEGURANÇA:
- UFW: $(ufw status | grep Status | awk '{print $2}')
- fail2ban: $(systemctl is-active fail2ban)
- AppArmor: $(systemctl is-active apparmor)
- Chrony: $(systemctl is-active chrony)
- Docker: $(systemctl is-active docker)

CONFIGURAÇÃO SSH (⚠️ DEV/TEST):
- Porta: 22
- Autenticação por senha: HABILITADA
- Root login com senha: HABILITADO
- Chave SSH: Também aceita
- MaxAuthTries: 3
- LoginGraceTime: 30s
- fail2ban: Ativo (3 falhas = ban 1h)

USUÁRIOS:
- root: Login com senha HABILITADO
- docker: sudo COM senha (membro do grupo sudo)
  Grupos: docker, sudo

FIREWALL:
- Política padrão: DENY incoming
- SSH (22): Rate limited
- Docker: Integrado com UFW

SEGURANÇA:
✓ Kernel hardening (otimizado 2GB)
✓ AppArmor ativo
✓ fail2ban (proteção agressiva)
✓ Atualizações automáticas de segurança
✓ Limpeza diária + semanal automática
✓ Swap 2GB ativado
✓ Logs rotacionados
✓ SSH banner configurado

⚠️ AVISOS DE SEGURANÇA:
✗ Root login com senha HABILITADO
✓ Sudo requer senha (melhora segurança)
✗ Configuração NÃO recomendada para produção

================================================
PRÓXIMOS PASSOS OBRIGATÓRIOS:
================================================

1. DEFINA SENHAS FORTES (mínimo 16 caracteres):
   
   passwd root
   passwd docker

2. TESTE SSH em OUTRA JANELA antes de desconectar:
   
   # Como root:
   ssh root@$(hostname -I | awk '{print $1}')
   
   # Como docker:
   ssh docker@$(hostname -I | awk '{print $1}')

3. Teste sudo com senha (como docker):
   
   ssh docker@$(hostname -I | awk '{print $1}')
   sudo su -
   # Deve PEDIR a senha do usuário docker

4. Após confirmar que tudo funciona, REINICIE:
   
   reboot

5. Após reiniciar, verifique serviços:
   
   vps-status
   fail2ban-status

6. Monitore logs de autenticação:
   
   tail -f /var/log/auth.log

================================================
COMANDOS ÚTEIS:
================================================

# Status geral da VPS:
vps-status

# Status do fail2ban:
fail2ban-status

# Ver IPs banidos:
fail2ban-client status sshd

# Desbloquear um IP:
sudo fail2ban-client set sshd unbanip IP_ADDRESS

# Uso de recursos:
htop

# Espaço em disco detalhado:
ncdu /

# Logs Docker:
docker logs <container_id>

# Logs do sistema:
journalctl -xe

# Últimas tentativas de login:
tail -50 /var/log/auth.log | grep sshd

# Limpar Docker manualmente:
docker system prune -af --volumes

# Ver processos por memória:
ps aux --sort=-%mem | head -20

# Containers rodando:
docker ps

# Restart serviços de segurança:
sudo systemctl restart fail2ban ufw

================================================
CONFIGURAÇÕES IMPORTANTES:
================================================

SSH Config: /etc/ssh/sshd_config.d/99-hardening.conf
fail2ban: /etc/fail2ban/jail.local
Firewall: ufw status verbose
Docker: /etc/docker/daemon.json
Sudo: /etc/sudoers.d/docker
Kernel: /etc/sysctl.d/99-hardening-vps.conf

Backup original SSH: /etc/ssh/sshd_config.backup.*

================================================
RECOMENDAÇÕES DE SEGURANÇA:
================================================

Para PRODUÇÃO, você DEVE:
1. Desabilitar root login com senha
2. Usar apenas chaves SSH
3. Exigir senha para sudo
4. Mudar porta SSH padrão (22)
5. Implementar 2FA (Google Authenticator)
6. Configurar monitoramento externo
7. Implementar backup automático

Para manter esta configuração DEV/TEST:
✓ Use SENHAS MUITO FORTES (16+ chars)
✓ Monitore /var/log/auth.log diariamente
✓ Revise fail2ban-status semanalmente
✓ Mantenha sistema atualizado
✓ NÃO exponha dados sensíveis

================================================
MONITORAMENTO CONTÍNUO:
================================================

fail2ban está configurado para:
- Banir após 3 tentativas falhas (1 hora)
- Banir após 6 tentativas DDOS (30 min)
- Banir após 5 tentativas em 1h (24 horas)

Logs importantes:
- /var/log/auth.log (tentativas de login)
- /var/log/fail2ban.log (bloqueios)
- /var/log/ufw.log (firewall)

================================================
REPORT

cat /root/hardening-report.txt

echo ""
echo -e "${GREEN}✔ Relatório completo salvo em: /root/hardening-report.txt${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  AÇÕES NECESSÁRIAS AGORA:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}1. Defina senhas FORTES (16+ caracteres):${NC}"
echo -e "   ${GREEN}passwd root${NC}"
echo -e "   ${GREEN}passwd docker${NC}"
echo ""
echo -e "${BLUE}2. TESTE SSH em OUTRA JANELA/TERMINAL:${NC}"
echo -e "   ${GREEN}ssh root@$(hostname -I | awk '{print $1}')${NC}"
echo -e "   ${GREEN}ssh docker@$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo -e "${BLUE}3. Teste sudo com senha (como docker):${NC}"
echo -e "   ${GREEN}ssh docker@$(hostname -I | awk '{print $1}')${NC}"
echo -e "   ${GREEN}sudo su -${NC}  ${YELLOW}# Deve PEDIR a senha do usuário docker${NC}"
echo ""
echo -e "${BLUE}4. Se tudo OK, reinicie nesta janela:${NC}"
echo -e "   ${GREEN}reboot${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}⚠️  NÃO FECHE ESTA JANELA ATÉ TESTAR!${NC}"
echo ""
echo -e "${YELLOW}Após reboot, execute: ${GREEN}vps-status${NC}"
echo ""
