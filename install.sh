#!/bin/bash

# Production Docker Host Hardening Script (based on https://gist.github.com/rameerez/238927b78f9108a71a77aed34208de11)
# For Ubuntu Server 22.04 LTS (Noble)

#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# =========================
# Configurações básicas
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
NC='\033[0m'

log() { echo -e "${YELLOW}▶ $1${NC}"; }
ok()  { echo -e "${GREEN}✔ $1${NC}"; }
die() { echo -e "${RED}✖ $1${NC}"; exit 1; }

trap 'die "Erro na linha $LINENO"' ERR

# =========================
# Pré-checks
# =========================
log "Validando ambiente..."

[[ $EUID -eq 0 ]] || die "Execute como root"

command -v lsb_release >/dev/null || die "lsb_release não encontrado"

UBUNTU_VERSION=$(lsb_release -rs)

dpkg --compare-versions "$UBUNTU_VERSION" ge "$MIN_UBUNTU_VERSION" \
  || die "Ubuntu $MIN_UBUNTU_VERSION ou superior é necessário (encontrado: $UBUNTU_VERSION)"

RAM=$(free -m | awk '/^Mem:/{print $2}')
DISK=$(df -BG / | awk 'NR==2{gsub("G","");print $4}')

(( RAM >= MIN_RAM_MB )) || die "RAM insuficiente: ${RAM}MB (mínimo: ${MIN_RAM_MB}MB)"
(( DISK >= MIN_DISK_GB )) || die "Disco insuficiente: ${DISK}GB (mínimo: ${MIN_DISK_GB}GB)"

ok "Sistema compatível (Ubuntu $UBUNTU_VERSION, ${RAM}MB RAM, ${DISK}GB disco)"

# =========================
# Atualização do sistema
# =========================
log "Atualizando pacotes..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# =========================
# Pacotes essenciais
# =========================
log "Instalando pacotes essenciais..."
apt-get install -y \
  ufw fail2ban curl wget gnupg ca-certificates \
  software-properties-common sysstat auditd \
  audispd-plugins unattended-upgrades acl \
  apparmor apparmor-utils aide aide-common logwatch \
  git chrony

# =========================
# Sincronização de tempo
# =========================
log "Configurando horário (chrony)..."
systemctl disable systemd-timesyncd --now 2>/dev/null || true
systemctl enable chrony --now

# Verificar se chrony está funcionando
sleep 2
if chronyc tracking &>/dev/null; then
  ok "Chrony sincronizando"
else
  log "AVISO: Chrony pode não estar sincronizando corretamente"
fi

# =========================
# Hardening de Kernel
# =========================
log "Aplicando hardening de kernel..."
cat >/etc/sysctl.d/99-hardening.conf <<'EOF'
# Randomização de memória
kernel.randomize_va_space=2
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.perf_event_paranoid=3
kernel.unprivileged_bpf_disabled=1

# Proteção de sistema de arquivos
fs.protected_hardlinks=1
fs.protected_symlinks=1
fs.suid_dumpable=0

# Rede - Docker precisa de IP forwarding
net.ipv4.ip_forward=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0

# IMPORTANTE: log_martians=0 para evitar spam de logs com Docker
# Docker usa NAT e vai gerar milhares de mensagens "martian source"
net.ipv4.conf.all.log_martians=0
net.ipv4.conf.default.log_martians=0

net.ipv4.tcp_syncookies=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1

# IPv6
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0

# Limites
fs.file-max=1048576
kernel.pid_max=65536
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
# AIDE
# =========================
log "Inicializando AIDE (pode demorar vários minutos)..."
if aide --init 2>&1 | grep -q "AIDE initialized"; then
  if [ -f /var/lib/aide/aide.db.new ]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    ok "AIDE inicializado"
  else
    log "AVISO: AIDE pode não ter criado o database corretamente"
  fi
else
  log "AVISO: AIDE pode ter falhado na inicialização"
fi

# =========================
# Docker
# =========================
log "Instalando Docker..."
curl -fsSL https://get.docker.com | sh
systemctl enable docker --now

log "Configurando Docker..."
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "userland-proxy": false,
  "no-new-privileges": true,
  "iptables": true,
  "storage-driver": "overlay2",
  "features": { "buildkit": true }
}
EOF

systemctl daemon-reload
systemctl restart docker || die "Docker falhou ao reiniciar"

# Aguardar Docker iniciar
sleep 3

# Verificar se Docker está funcionando
if docker info &>/dev/null; then
  ok "Docker instalado e funcionando"
else
  die "Docker não está respondendo"
fi

# =========================
# Usuário docker
# =========================
log "Criando usuário docker..."
if ! id docker &>/dev/null; then
  adduser --disabled-password --gecos "" docker
fi
usermod -aG docker docker

# Setup home directory
mkdir -p /home/docker/.ssh
chmod 700 /home/docker/.ssh
chown -R docker:docker /home/docker

# Copiar chaves SSH se existirem
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/docker/.ssh/authorized_keys
  chmod 600 /home/docker/.ssh/authorized_keys
  chown docker:docker /home/docker/.ssh/authorized_keys
  ok "Chaves SSH copiadas para usuário docker"
else
  log "AVISO: Nenhuma chave SSH encontrada em /root/.ssh/authorized_keys"
  log "       Adicione manualmente em /home/docker/.ssh/authorized_keys"
fi

# =========================
# SSH (MODULAR, SEGURO)
# =========================
log "Endurecendo SSH..."
mkdir -p /etc/ssh/sshd_config.d

cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
# Autenticação
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
ChallengeResponseAuthentication no

# Recursos
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding no

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30

# Usuários permitidos
AllowUsers docker root

# Algoritmos seguros
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
EOF

# Testar configuração antes de aplicar
if sshd -t 2>/dev/null; then
  systemctl reload ssh
  ok "SSH endurecido"
else
  die "Configuração SSH inválida! Verifique /etc/ssh/sshd_config.d/99-hardening.conf"
fi

# =========================
# Firewall
# =========================
log "Configurando firewall (com suporte Docker)..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH

# Se você precisa de HTTP/HTTPS, descomente:
# ufw allow 80/tcp
# ufw allow 443/tcp

# CRÍTICO: Integração UFW + Docker
mkdir -p /etc/ufw
cat >>/etc/ufw/after.rules <<'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]

# Permite tráfego de redes privadas (Docker)
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

# Encaminha para regras personalizadas
-A DOCKER-USER -j ufw-user-forward

# Drop conexões novas não autorizadas
-A DOCKER-USER -j DROP -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW

COMMIT
# END UFW AND DOCKER
EOF

ufw --force enable
ok "Firewall configurado"

# =========================
# fail2ban
# =========================
log "Configurando fail2ban..."
cat >/etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
EOF

systemctl enable fail2ban --now
ok "fail2ban ativo"

# =========================
# Auditd
# =========================
log "Configurando auditd para monitorar Docker..."
cat >/etc/audit/rules.d/docker.rules <<'EOF'
# Monitoramento Docker
-w /usr/bin/dockerd -p wa -k docker_daemon
-w /var/lib/docker -p wa -k docker_data
-w /etc/docker -p wa -k docker_config
-w /usr/bin/docker -p wa -k docker_client
-w /var/run/docker.sock -p wa -k docker_socket
EOF

augenrules --load
systemctl restart auditd
ok "Auditd configurado"

# =========================
# Logrotate Docker
# =========================
log "Configurando rotação de logs do Docker..."
cat >/etc/logrotate.d/docker <<'EOF'
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  size=100M
  missingok
  delaycompress
  copytruncate
}
EOF

# =========================
# Limpeza automática Docker
# =========================
log "Configurando limpeza automática do Docker..."
cat >/etc/cron.daily/docker-cleanup <<'EOF'
#!/bin/bash
# Limpa imagens, containers e volumes não usados há mais de 72h
docker system prune -af --volumes --filter "until=72h" >/dev/null 2>&1
EOF
chmod +x /etc/cron.daily/docker-cleanup
ok "Cron de limpeza configurado"

# =========================
# Atualizações automáticas
# =========================
log "Ativando atualizações automáticas de segurança..."
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

dpkg-reconfigure -f noninteractive unattended-upgrades
ok "Atualizações automáticas ativas"

# =========================
# Limpeza final
# =========================
apt-get autoremove -y
apt-get clean

# =========================
# Relatório final
# =========================
echo ""
ok "========================================="
ok "  INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
ok "========================================="
echo ""
echo "Sistema: Ubuntu $UBUNTU_VERSION"
echo "Docker: $(docker --version)"
echo "AppArmor: $(aa-status --enabled && echo 'Ativo' || echo 'Inativo')"
echo "UFW: $(ufw status | grep Status)"
echo "fail2ban: $(systemctl is-active fail2ban)"
echo "Chrony: $(systemctl is-active chrony)"
echo ""
echo "⚠️  PRÓXIMOS PASSOS OBRIGATÓRIOS:"
echo ""
echo "1. Adicione sua chave SSH pública em:"
echo "   /home/docker/.ssh/authorized_keys"
echo ""
echo "2. TESTE a conexão SSH como usuário 'docker' em outra janela:"
echo "   ssh docker@seu-servidor"
echo ""
echo "3. SOMENTE após confirmar que SSH funciona, reinicie:"
echo "   sudo reboot"
echo ""
echo "4. Após reiniciar, verifique os serviços:"
echo "   systemctl status docker fail2ban ufw auditd chrony"
echo ""
echo "5. Configure monitoramento externo e backups"
echo ""
echo "⚠️  AVISO: Autenticação por senha está DESABILITADA!"
echo "   Certifique-se de ter acesso via chave SSH antes de desconectar."
echo ""
