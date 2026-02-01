#!/bin/bash

# VPS Hardening Script - Versão Final Corrigida
# Para Ubuntu 22.04+ | VPS Compartilhada (2 vCPU / 4GB RAM)
# Segurança robusta + Performance + Suporte a senha

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
die() { echo -e "${RED}✖ $1${NC}"; exit 1; }

trap 'die "Erro na linha $LINENO"' ERR

# =========================
# Banner
# =========================
clear
cat << "EOF"
╔═══════════════════════════════════════════════╗
║   VPS Hardening - Versão Final Corrigida     ║
║   Segurança + Performance + Flexibilidade     ║
╚═══════════════════════════════════════════════╝
EOF
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
# Confirmação
# =========================
info "Esta configuração permite login com SENHA (protegido por fail2ban)"
info "Recomendado para ambientes de desenvolvimento/teste"
echo ""
read -p "Continuar com a instalação? (s/N): " -n 1 -r
echo
[[ ! $REPLY =~ ^[Ss]$ ]] && die "Instalação cancelada"

# =========================
# Atualização do sistema
# =========================
log "Atualizando sistema (pode demorar alguns minutos)..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

# =========================
# Pacotes essenciais (apenas o necessário)
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
  apt-listchanges

ok "Pacotes instalados"

# =========================
# Sincronização de tempo
# =========================
log "Configurando sincronização de tempo (chrony)..."
systemctl disable systemd-timesyncd --now 2>/dev/null || true

cat >/etc/chrony/chrony.conf <<'EOF'
pool 2.ubuntu.pool.ntp.org iburst maxsources 2
pool 2.south-america.pool.ntp.org iburst maxsources 1
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
EOF

systemctl enable chrony --now
sleep 2

if chronyc tracking &>/dev/null; then
  ok "Chrony sincronizando"
else
  log "AVISO: Chrony pode não estar sincronizando (normal em VPS)"
fi

# =========================
# Hardening de Kernel (LEVE)
# =========================
log "Aplicando hardening de kernel (otimizado para VPS)..."
cat >/etc/sysctl.d/99-hardening-lite.conf <<'EOF'
# Proteção de filesystem
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.suid_dumpable=0

# Rede - Balanceado para VPS + Docker
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0

# IMPORTANTE: log_martians=0 para evitar spam com Docker
net.ipv4.conf.all.log_martians=0
net.ipv4.conf.default.log_martians=0

net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

# IPv6 (desabilitar se não usar)
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0

# Limites adequados para VPS pequena
fs.file-max=524288
kernel.pid_max=32768
EOF

sysctl --system >/dev/null
ok "Parâmetros de kernel aplicados"

# =========================
# AppArmor
# =========================
log "Ativando AppArmor..."
systemctl enable apparmor --now
ok "AppArmor ativo"

# =========================
# Docker
# =========================
log "Instalando Docker..."
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  ok "Docker instalado"
else
  ok "Docker já instalado"
fi

systemctl enable docker --now

log "Configurando Docker (otimizado para VPS)..."
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",
    "max-file": "3"
  },
  "userland-proxy": false,
  "no-new-privileges": true,
  "iptables": true,
  "storage-driver": "overlay2",
  "live-restore": true,
  "features": { "buildkit": true }
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
# Usuário docker - CORRIGIDO
# =========================
log "Configurando usuário docker..."

# Desabilitar exit on error temporariamente para esta seção
set +e

if ! id docker &>/dev/null 2>&1; then
  # Usar useradd ao invés de adduser para evitar conflito com grupo
  useradd -m -s /bin/bash -g docker docker 2>/dev/null
  
  if id docker &>/dev/null 2>&1; then
    ok "Usuário docker criado"
  else
    # Se falhar, tentar criar o grupo primeiro
    groupadd -f docker 2>/dev/null
    useradd -m -s /bin/bash -g docker docker 2>/dev/null
    
    if id docker &>/dev/null 2>&1; then
      ok "Usuário docker criado"
    else
      set -e
      die "Falha ao criar usuário docker"
    fi
  fi
else
  ok "Usuário docker já existe"
fi

# Reabilitar exit on error
set -e

# Setup SSH directory
mkdir -p /home/docker/.ssh
chmod 700 /home/docker/.ssh
chown -R docker:docker /home/docker

# Copiar chaves SSH se existirem
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/docker/.ssh/authorized_keys
  chmod 600 /home/docker/.ssh/authorized_keys
  chown docker:docker /home/docker/.ssh/authorized_keys
  ok "Chaves SSH copiadas para usuário docker"
fi

# =========================
# SSH Hardening (COM SENHA)
# =========================
log "Configurando SSH (com suporte a senha + proteções extras)..."

# Backup
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)

mkdir -p /etc/ssh/sshd_config.d

cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
# Autenticação - PERMITE SENHA (com limitações)
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin prohibit-password
ChallengeResponseAuthentication no
PermitEmptyPasswords no

# Segurança extra para compensar uso de senha
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30

# Recursos
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding no

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2

# Usuários permitidos
AllowUsers docker root

# Logging detalhado (importante com senha habilitada)
LogLevel VERBOSE
SyslogFacility AUTH

# Algoritmos seguros (balanceado)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF

# Testar configuração
if sshd -t 2>/dev/null; then
  systemctl reload ssh
  ok "SSH configurado (SENHA HABILITADA com proteções)"
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
ufw allow OpenSSH

# Adicione portas extras se necessário:
# ufw allow 80/tcp
# ufw allow 443/tcp

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

# Drop inválidos
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP
-A DOCKER-USER -j RETURN

COMMIT
# END UFW AND DOCKER
EOF

ufw --force enable
ok "Firewall ativo"

# =========================
# fail2ban (CRÍTICO com senha habilitada)
# =========================
log "Configurando fail2ban (proteção essencial contra brute-force)..."
cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# Configuração agressiva devido ao uso de senha
bantime = 3600
findtime = 600
maxretry = 3
destemail = root@localhost

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

# Proteção extra contra scans
[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 6
bantime = 600
EOF

# Criar filtro extra para DDOS
cat >/etc/fail2ban/filter.d/sshd-ddos.conf <<'EOF'
[Definition]
failregex = ^%(__prefix_line)sDid not receive identification string from <HOST>\s*$
            ^%(__prefix_line)sConnection (closed|reset) by <HOST> port \d+\s*$
ignoreregex =
EOF

systemctl enable fail2ban --now
ok "fail2ban ativo (proteção contra brute-force)"

# =========================
# Limites de recursos
# =========================
log "Configurando limites de recursos..."
cat >/etc/security/limits.d/vps.conf <<'EOF'
# Limites para VPS compartilhada
* soft nofile 4096
* hard nofile 8192
* soft nproc 2048
* hard nproc 4096
EOF

ok "Limites configurados"

# =========================
# Limpeza automática Docker
# =========================
log "Configurando limpeza automática..."
cat >/etc/cron.weekly/docker-cleanup <<'EOF'
#!/bin/bash
# Limpeza Docker + Sistema

# Docker (imagens/containers não usados há 7+ dias)
docker system prune -af --volumes --filter "until=168h" >/dev/null 2>&1

# Logs antigos
find /var/log -type f -name "*.gz" -mtime +30 -delete
find /var/log -type f -name "*.1" -mtime +7 -delete

# APT
apt-get clean
apt-get autoremove -y
EOF

chmod +x /etc/cron.weekly/docker-cleanup
ok "Cron de limpeza configurado"

# =========================
# Atualizações automáticas
# =========================
log "Configurando atualizações automáticas de segurança..."
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
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
ok "Permissões ajustadas"

# =========================
# Logwatch (relatórios semanais)
# =========================
log "Configurando logwatch..."
cat >/etc/cron.weekly/00logwatch <<'EOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail low
EOF
chmod +x /etc/cron.weekly/00logwatch
ok "Logwatch configurado"

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
RELATÓRIO DE HARDENING - VPS LITE
Data: $(date)
Hostname: $(hostname)
================================================

SISTEMA:
- OS: Ubuntu $UBUNTU_VERSION
- RAM: ${RAM}MB
- Disco livre: ${DISK}GB
- Docker: $(docker --version 2>/dev/null || echo "Não instalado")

SERVIÇOS DE SEGURANÇA:
- UFW: $(ufw status | grep Status | awk '{print $2}')
- fail2ban: $(systemctl is-active fail2ban)
- AppArmor: $(systemctl is-active apparmor)
- Chrony: $(systemctl is-active chrony)
- Docker: $(systemctl is-active docker)

CONFIGURAÇÃO SSH:
- Porta: 22
- Senha: HABILITADA (com fail2ban ativo)
- Root login: Apenas com chave SSH
- MaxAuthTries: 3
- fail2ban: Bane após 3 tentativas falhas

USUÁRIOS:
- docker (grupo docker): OK
- root: Login apenas com chave SSH

FIREWALL:
- Política padrão: DENY incoming
- SSH (22): PERMITIDO
- Docker: Integrado com UFW

SEGURANÇA:
✓ Kernel hardening (leve)
✓ AppArmor ativo
✓ fail2ban protegendo SSH
✓ Atualizações automáticas de segurança
✓ Limpeza semanal automática
✓ Logs rotacionados

================================================
PRÓXIMOS PASSOS OBRIGATÓRIOS:
================================================

1. DEFINA UMA SENHA FORTE para o usuário docker:
   passwd docker

2. (Opcional) Adicione chaves SSH:
   Adicione em /home/docker/.ssh/authorized_keys
   Depois desabilite senha em /etc/ssh/sshd_config.d/99-hardening.conf

3. TESTE a conexão SSH em OUTRA JANELA (não feche esta):
   ssh docker@seu-servidor
   OU
   ssh root@seu-servidor  (apenas com chave SSH)

4. Após confirmar que SSH funciona, reinicie:
   reboot

5. Após reiniciar, verifique os serviços:
   systemctl status docker fail2ban ufw chrony

6. Monitore tentativas de login:
   tail -f /var/log/auth.log
   fail2ban-client status sshd

7. Configure backup externo e monitoramento

================================================
AVISOS IMPORTANTES:
================================================

⚠️  AUTENTICAÇÃO POR SENHA HABILITADA
    - fail2ban está protegendo (3 tentativas = ban de 1h)
    - Use SENHA FORTE (mínimo 16 caracteres)
    - Monitore /var/log/auth.log regularmente

⚠️  ROOT LOGIN
    - Root só aceita chave SSH (senha desabilitada)
    - Use usuário 'docker' para acesso normal

⚠️  BACKUP ESSENCIAL
    - Configure backup automático
    - Teste restauração regularmente

================================================
COMANDOS ÚTEIS:
================================================

# Ver tentativas de login bloqueadas:
fail2ban-client status sshd

# Desbloquear um IP:
fail2ban-client set sshd unbanip IP_ADDRESS

# Ver uso de recursos:
htop

# Logs do sistema:
journalctl -xe

# Logs de autenticação:
tail -f /var/log/auth.log

================================================
REPORT

cat /root/hardening-report.txt

echo ""
echo -e "${GREEN}✔ Relatório completo salvo em: /root/hardening-report.txt${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo -e "${RED}⚠️  AÇÃO NECESSÁRIA AGORA:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}1. Defina senha para usuário docker:${NC}"
echo -e "   ${GREEN}passwd docker${NC}"
echo ""
echo -e "${BLUE}2. ABRA OUTRA JANELA/TERMINAL SSH e teste ANTES de desconectar:${NC}"
echo -e "   ${GREEN}ssh docker@$(hostname -I | awk '{print $1}')${NC}"
echo ""
echo -e "${BLUE}3. Se conseguir logar na outra janela, volte aqui e reinicie:${NC}"
echo -e "   ${GREEN}reboot${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════${NC}"
echo ""
echo -e "${RED}⚠️  NÃO FECHE ESTA JANELA ATÉ TESTAR SSH NA OUTRA!${NC}"
echo ""
