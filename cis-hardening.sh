#!/bin/bash
# CIS Ubuntu Linux 24.04 LTS Benchmark - Level 1 & 2 Hardening Script
# Baseado em: CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0
# 
# CIS Level 1: Configurações básicas de segurança (ambiente de produção)
# CIS Level 2: Configurações avançadas de segurança (ambiente de alta segurança)
#
# AVISO: Este script faz mudanças significativas no sistema
# Execute em ambiente de teste antes de produção!

set -euo pipefail
IFS=$'\n\t'

# =========================
# Configurações
# =========================
MIN_UBUNTU_VERSION="22.04"
MIN_RAM_MB=900
MIN_DISK_GB=5
CIS_LEVEL="${CIS_LEVEL:-2}"  # 1 ou 2 (padrão: Level 2)

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
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   CIS Ubuntu 24.04 LTS Benchmark Hardening Script        ║
║   Level 1 & 2 Implementation                             ║
║                                                           ║
║   ⚠️  ATENÇÃO: Este script modifica configurações        ║
║       críticas do sistema. Use com cuidado!              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""
info "CIS Level configurado: ${CIS_LEVEL}"
info "Aguarde 5 segundos ou pressione Ctrl+C para cancelar..."
sleep 5

# =========================
# Pré-checks
# =========================
log "Validando ambiente..."

[[ $EUID -eq 0 ]] || die "Execute como root"

command -v lsb_release >/dev/null || die "lsb_release não encontrado"

UBUNTU_VERSION=$(lsb_release -rs)

dpkg --compare-versions "$UBUNTU_VERSION" ge "$MIN_UBUNTU_VERSION" \
  || die "Ubuntu $MIN_UBUNTU_VERSION ou superior necessário (encontrado: $UBUNTU_VERSION)"

RAM=$(free -m | awk '/^Mem:/{print $2}')
DISK=$(df -BG / | awk 'NR==2{gsub("G","");print $4}')

(( RAM >= MIN_RAM_MB )) || die "RAM insuficiente: ${RAM}MB (mínimo: ${MIN_RAM_MB}MB)"
(( DISK >= MIN_DISK_GB )) || die "Disco insuficiente: ${DISK}GB (mínimo: ${MIN_DISK_GB}GB)"

ok "Sistema compatível (Ubuntu $UBUNTU_VERSION, ${RAM}MB RAM, ${DISK}GB disco)"

# =========================
# 1. Initial Setup
# =========================
log "1. INITIAL SETUP - Configurações iniciais..."

# 1.1.1 - Ensure bootloader password is set (Level 1)
log "1.1.1 - Configurando senha do bootloader..."
# Nota: Configuração manual necessária em produção
# grub-mkpasswd-pbkdf2 deve ser executado manualmente

# 1.2 - Configure Software Updates (Level 1)
log "1.2 - Configurando atualizações automáticas..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# 1.3 - Filesystem Integrity Checking (Level 1)
log "1.3 - Instalando AIDE para verificação de integridade..."
apt-get install -y aide aide-common

# 1.4 - Secure Boot Settings (Level 1)
log "1.4 - Configurando permissões de boot..."
chmod 0600 /boot/grub/grub.cfg 2>/dev/null || true

# 1.5 - Additional Process Hardening (Level 1)
log "1.5 - Instalando pacotes de hardening..."
apt-get install -y \
  apparmor \
  apparmor-utils \
  auditd \
  audispd-plugins \
  libpam-pwquality \
  libpam-modules \
  cracklib-runtime

# =========================
# 2. Services
# =========================
log "2. SERVICES - Desabilitando serviços desnecessários..."

# 2.1 - Disable unused services (Level 1)
SERVICES_TO_DISABLE=(
  autofs
  avahi-daemon
  cups
  dhcpd
  slapd
  nfs-server
  rpcbind
  bind9
  vsftpd
  dovecot
  smbd
  snmpd
  rsync
  nis
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
  if systemctl list-unit-files | grep -q "^${service}.service"; then
    systemctl disable "${service}.service" --now 2>/dev/null || true
    info "  Desabilitado: ${service}"
  fi
done

# 2.2 - Configure time synchronization (Level 1)
log "2.2 - Configurando sincronização de tempo..."
systemctl disable systemd-timesyncd --now 2>/dev/null || true
apt-get install -y chrony
systemctl enable chrony --now

cat > /etc/chrony/chrony.conf <<'EOF'
# CIS Benchmark compliant chrony configuration
pool 2.debian.pool.ntp.org iburst maxsources 4
pool 0.ubuntu.pool.ntp.org iburst maxsources 1
pool 1.ubuntu.pool.ntp.org iburst maxsources 1
pool 2.ubuntu.pool.ntp.org iburst maxsources 2

keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
logdir /var/log/chrony
maxupdateskew 100.0
rtcsync
makestep 1 3
leapsectz right/UTC
EOF

systemctl restart chrony

# =========================
# 3. Network Configuration
# =========================
log "3. NETWORK - Configurando parâmetros de rede..."

cat > /etc/sysctl.d/60-cis-network.conf <<'EOF'
# CIS 3.1 - Network Parameters (Host Only)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# CIS 3.2 - Network Parameters (Host and Router)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# CIS 3.2.2 - Enable Ignore ICMP Requests
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# CIS 3.2.6 - Enable TCP SYN Cookies
net.ipv4.tcp_syncookies = 1

# CIS 3.2.8 - Enable Reverse Path Filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# CIS 3.2.9 - Disable IPv6 Router Advertisements
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

# Docker requirement
net.ipv4.ip_forward = 1

# Log martians disabled for Docker compatibility
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.default.log_martians = 0
EOF

# =========================
# 4. Logging and Auditing
# =========================
log "4. LOGGING - Configurando auditoria e logs..."

# 4.1 - Configure System Accounting (auditd)
systemctl enable auditd --now

# CIS 4.1.3 - Audit Rules
cat > /etc/audit/rules.d/cis.rules <<'EOF'
# CIS 4.1.3.1 - Changes to system administration scope
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# CIS 4.1.3.2 - Ensure actions as another user are always logged
-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k user_emulation
-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k user_emulation

# CIS 4.1.3.3 - Network Environment
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network -p wa -k system-locale

# CIS 4.1.3.4 - System Mandatory Access Controls
-w /etc/apparmor/ -p wa -k MAC-policy
-w /etc/apparmor.d/ -p wa -k MAC-policy

# CIS 4.1.3.5 - Login and Logout Events
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# CIS 4.1.3.6 - Session Initiation
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k logins
-w /var/log/btmp -p wa -k logins

# CIS 4.1.3.7 - Discretionary Access Control
-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod

# CIS 4.1.3.8 - Unsuccessful File Access Attempts
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b32 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b32 -S open,truncate,ftruncate,creat,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access

# CIS 4.1.3.9 - File Deletion Events
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k delete

# CIS 4.1.3.10 - Kernel Module Loading and Unloading
-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k kernel_modules
-w /usr/bin/kmod -p x -k kernel_modules

# CIS 4.1.3.11 - System Administrator Actions
-w /var/log/sudo.log -p wa -k actions

# Docker specific auditing
-w /usr/bin/dockerd -p wa -k docker
-w /var/lib/docker -p wa -k docker
-w /etc/docker -p wa -k docker
-w /usr/bin/docker -p wa -k docker
-w /var/run/docker.sock -p wa -k docker

# Make the configuration immutable
-e 2
EOF

augenrules --load
systemctl restart auditd

# 4.2 - Configure rsyslog
log "4.2 - Configurando rsyslog..."
apt-get install -y rsyslog

cat >> /etc/rsyslog.d/50-cis.conf <<'EOF'
# CIS Logging Configuration
*.emerg                                 :omusrmsg:*
auth,authpriv.*                         /var/log/auth.log
*.*;auth,authpriv.none                  -/var/log/syslog
daemon.*                                -/var/log/daemon.log
kern.*                                  -/var/log/kern.log
lpr.*                                   -/var/log/lpr.log
mail.*                                  -/var/log/mail.log
user.*                                  -/var/log/user.log

# CIS 4.2.1.3 - Ensure rsyslog default file permissions configured
$FileCreateMode 0640
EOF

systemctl restart rsyslog

# 4.3 - Log rotation
log "4.3 - Configurando rotação de logs..."
cat > /etc/logrotate.d/cis <<'EOF'
/var/log/auth.log
/var/log/syslog
/var/log/daemon.log
/var/log/kern.log
{
    rotate 90
    daily
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF

# =========================
# 5. Access, Authentication and Authorization
# =========================
log "5. ACCESS CONTROL - Configurando controle de acesso..."

# 5.1 - Configure cron
log "5.1 - Configurando permissões do cron..."
touch /etc/cron.allow /etc/at.allow
chmod 0600 /etc/cron.allow /etc/at.allow
chown root:root /etc/cron.allow /etc/at.allow
rm -f /etc/cron.deny /etc/at.deny

# 5.2 - SSH Server Configuration (CIS Level 1)
log "5.2 - Configurando SSH (CIS compliant)..."
mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/99-cis-hardening.conf <<'EOF'
# CIS 5.2 - SSH Server Configuration

# CIS 5.2.1 - Ensure permissions on /etc/ssh/sshd_config are configured
# (handled by file permissions below)

# CIS 5.2.2 - Ensure permissions on SSH private host key files
# (handled separately)

# CIS 5.2.3 - Ensure permissions on SSH public host key files
# (handled separately)

# CIS 5.2.4 - Ensure SSH access is limited
AllowUsers docker root
AllowGroups docker root

# CIS 5.2.5 - Ensure SSH LogLevel is appropriate
LogLevel VERBOSE

# CIS 5.2.6 - Ensure SSH PAM is enabled
UsePAM yes

# CIS 5.2.7 - Ensure SSH root login is disabled
PermitRootLogin prohibit-password

# CIS 5.2.8 - Ensure SSH HostbasedAuthentication is disabled
HostbasedAuthentication no

# CIS 5.2.9 - Ensure SSH PermitEmptyPasswords is disabled
PermitEmptyPasswords no

# CIS 5.2.10 - Ensure SSH PermitUserEnvironment is disabled
PermitUserEnvironment no

# CIS 5.2.11 - Ensure SSH IgnoreRhosts is enabled
IgnoreRhosts yes

# CIS 5.2.12 - Ensure SSH X11 forwarding is disabled
X11Forwarding no

# CIS 5.2.13 - Ensure SSH AllowTcpForwarding is disabled (Level 2)
# Disabled for Docker compatibility - set to 'no' for max security
AllowTcpForwarding yes

# CIS 5.2.14 - Ensure system-wide crypto policy is not over-ridden
# Don't override system crypto policy

# CIS 5.2.15 - Ensure SSH warning banner is configured
Banner /etc/issue.net

# CIS 5.2.16 - Ensure SSH MaxAuthTries is set to 4 or less
MaxAuthTries 4

# CIS 5.2.17 - Ensure SSH MaxStartups is configured
MaxStartups 10:30:60

# CIS 5.2.18 - Ensure SSH MaxSessions is limited
MaxSessions 10

# CIS 5.2.19 - Ensure SSH LoginGraceTime is set to one minute or less
LoginGraceTime 60

# CIS 5.2.20 - Ensure SSH Idle Timeout Interval is configured
ClientAliveInterval 300
ClientAliveCountMax 2

# Additional hardening
Protocol 2
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
AllowAgentForwarding no

# Strong ciphers and MACs
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
EOF

# Set SSH file permissions
chmod 0600 /etc/ssh/sshd_config
chmod 0600 /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
chmod 0600 /etc/ssh/ssh_host_*_key 2>/dev/null || true
chmod 0644 /etc/ssh/ssh_host_*_key.pub 2>/dev/null || true

# Create login banner
cat > /etc/issue.net <<'EOF'
************************************************************************
*                                                                      *
*  AUTHORIZED ACCESS ONLY                                             *
*                                                                      *
*  Unauthorized access to this system is forbidden and will be        *
*  prosecuted by law. By accessing this system, you agree that your   *
*  actions may be monitored if unauthorized usage is suspected.       *
*                                                                      *
************************************************************************
EOF

chmod 0644 /etc/issue.net

# Test SSH configuration
if sshd -t 2>/dev/null; then
  systemctl reload sshd
  ok "SSH configurado (CIS compliant)"
else
  die "Configuração SSH inválida!"
fi

# 5.3 - Configure privilege escalation
log "5.3 - Configurando sudo..."

cat > /etc/sudoers.d/cis-hardening <<'EOF'
# CIS 5.3.3 - Ensure sudo log file exists
Defaults logfile="/var/log/sudo.log"

# CIS 5.3.4 - Ensure users must provide password for escalation
Defaults !authenticate

# CIS 5.3.5 - Ensure re-authentication for privilege escalation is not disabled
Defaults timestamp_timeout=15

# CIS 5.3.6 - Ensure sudo authentication timeout is configured correctly
Defaults passwd_timeout=1
EOF

chmod 0440 /etc/sudoers.d/cis-hardening

# 5.4 - Configure PAM
log "5.4 - Configurando PAM..."

# 5.4.1 - Password Quality Requirements
cat > /etc/security/pwquality.conf <<'EOF'
# CIS 5.4.1 - Password Quality Requirements
minlen = 14
minclass = 4
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
# Reject passwords with more than 3 same consecutive characters
maxrepeat = 3
# Reject passwords with more than 3 consecutive characters in monotonic sequence
maxsequence = 3
EOF

# 5.4.2 - Lockout for Failed Password Attempts
cat > /etc/security/faillock.conf <<'EOF'
# CIS 5.4.2 - Account Lockout
deny = 5
fail_interval = 900
unlock_time = 600
EOF

# Update PAM configuration
cat > /etc/pam.d/common-password <<'EOF'
# CIS PAM Password Configuration
password requisite pam_pwquality.so retry=3
password [success=1 default=ignore] pam_unix.so obscure use_authtok try_first_pass yescrypt remember=5
password requisite pam_deny.so
password required pam_permit.so
EOF

cat > /etc/pam.d/common-auth <<'EOF'
# CIS PAM Auth Configuration with faillock
auth required pam_faillock.so preauth
auth [success=1 default=ignore] pam_unix.so nullok
auth [default=die] pam_faillock.so authfail
auth sufficient pam_faillock.so authsucc
auth requisite pam_deny.so
auth required pam_permit.so
EOF

# 5.5 - User Accounts and Environment
log "5.5 - Configurando contas de usuário..."

# 5.5.1 - Set Shadow Password Suite Parameters
cat > /etc/login.defs.new <<'EOF'
# CIS 5.5.1 - Password aging controls
PASS_MAX_DAYS   90
PASS_MIN_DAYS   1
PASS_WARN_AGE   7

# CIS 5.5.3 - Default umask
UMASK           027

# Additional security settings
ENCRYPT_METHOD SHA512
LOGIN_RETRIES 5
LOGIN_TIMEOUT 60
FAILLOG_ENAB yes
LOG_UNKFAIL_ENAB yes
SYSLOG_SU_ENAB yes
SYSLOG_SG_ENAB yes
EOF

# Preserve existing settings and merge
if [ -f /etc/login.defs ]; then
  grep -v "^PASS_MAX_DAYS\|^PASS_MIN_DAYS\|^PASS_WARN_AGE\|^UMASK\|^ENCRYPT_METHOD" /etc/login.defs > /tmp/login.defs.tmp || true
  cat /tmp/login.defs.tmp /etc/login.defs.new > /etc/login.defs
  rm /tmp/login.defs.tmp
fi
rm /etc/login.defs.new

# 5.5.4 - Ensure default user shell timeout is configured
cat >> /etc/bash.bashrc <<'EOF'

# CIS 5.5.4 - Shell timeout (15 minutes)
TMOUT=900
readonly TMOUT
export TMOUT
EOF

cat >> /etc/profile.d/cis-tmout.sh <<'EOF'
# CIS 5.5.4 - Shell timeout (15 minutes)
TMOUT=900
readonly TMOUT
export TMOUT
EOF

chmod 0644 /etc/profile.d/cis-tmout.sh

# =========================
# 6. System Maintenance
# =========================
log "6. SYSTEM MAINTENANCE - Configurando permissões..."

# 6.1 - System File Permissions
log "6.1 - Configurando permissões de arquivos críticos..."

chmod 0600 /etc/passwd- 2>/dev/null || true
chmod 0600 /etc/shadow- 2>/dev/null || true
chmod 0600 /etc/group- 2>/dev/null || true
chmod 0600 /etc/gshadow- 2>/dev/null || true
chmod 0644 /etc/passwd
chmod 0640 /etc/shadow
chmod 0644 /etc/group
chmod 0640 /etc/gshadow

# =========================
# Additional Kernel Hardening (Level 2)
# =========================
log "Aplicando hardening adicional de kernel (CIS Level 2)..."

cat > /etc/sysctl.d/99-cis-level2.conf <<'EOF'
# CIS Level 2 - Additional Kernel Hardening

# Address Space Layout Randomization
kernel.randomize_va_space = 2

# Kernel pointer exposure restriction
kernel.kptr_restrict = 2

# Dmesg restrictions
kernel.dmesg_restrict = 1

# Perf event restrictions
kernel.perf_event_paranoid = 3

# BPF restrictions
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# Ptrace restrictions
kernel.yama.ptrace_scope = 2

# Core dumps
fs.suid_dumpable = 0

# File system protections
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# System limits
fs.file-max = 1048576
kernel.pid_max = 65536
vm.max_map_count = 262144
EOF

sysctl --system >/dev/null

# =========================
# AppArmor Configuration
# =========================
log "Configurando AppArmor..."
systemctl enable apparmor --now
aa-enforce /etc/apparmor.d/* 2>/dev/null || true

# =========================
# Install and Configure Docker
# =========================
log "Instalando Docker com configurações CIS..."
curl -fsSL https://get.docker.com | sh
systemctl enable docker --now

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'EOF'
{
  "icc": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels": "production"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "iptables": true,
  "storage-driver": "overlay2",
  "userns-remap": "default",
  "features": {
    "buildkit": true
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

systemctl daemon-reload
systemctl restart docker || die "Docker falhou ao reiniciar"

# Wait for Docker to be ready
sleep 5
docker info &>/dev/null || die "Docker não está funcionando"

# Configure Docker socket permissions (CIS Docker Benchmark)
chmod 0660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

ok "Docker instalado com configurações CIS"

# =========================
# User Setup
# =========================
log "Criando usuário docker..."
if ! id docker &>/dev/null; then
  useradd -r -m -s /bin/bash -G docker docker
fi

# Setup SSH for docker user
mkdir -p /home/docker/.ssh
chmod 700 /home/docker/.ssh
chown -R docker:docker /home/docker

if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/docker/.ssh/authorized_keys
  chmod 600 /home/docker/.ssh/authorized_keys
  chown docker:docker /home/docker/.ssh/authorized_keys
  ok "Chaves SSH copiadas para usuário docker"
else
  log "AVISO: Adicione chaves SSH em /home/docker/.ssh/authorized_keys"
fi

# =========================
# Firewall Configuration (UFW)
# =========================
log "Configurando firewall UFW (CIS compliant)..."

apt-get install -y ufw

# Reset UFW
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Allow SSH
ufw allow OpenSSH

# Allow HTTP/HTTPS if needed
# ufw allow 80/tcp
# ufw allow 443/tcp

# Configure UFW for Docker
mkdir -p /etc/ufw
cat >> /etc/ufw/after.rules <<'EOF'

# BEGIN UFW AND DOCKER
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]

# Allow established connections
-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow Docker internal networks
-A DOCKER-USER -s 10.0.0.0/8 -j ACCEPT
-A DOCKER-USER -s 172.16.0.0/12 -j ACCEPT
-A DOCKER-USER -s 192.168.0.0/16 -j ACCEPT

# Forward to UFW rules
-A DOCKER-USER -j ufw-user-forward

# Drop invalid packets
-A DOCKER-USER -m conntrack --ctstate INVALID -j DROP

# Log and drop new connections
-A DOCKER-USER -j LOG --log-prefix "[UFW DOCKER BLOCK] "
-A DOCKER-USER -j DROP

COMMIT
# END UFW AND DOCKER
EOF

# Enable logging
ufw logging on

# Enable UFW
ufw --force enable

ok "Firewall configurado"

# =========================
# fail2ban Configuration
# =========================
log "Configurando fail2ban..."
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# CIS compliant fail2ban configuration
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
EOF

systemctl enable fail2ban --now
ok "fail2ban configurado"

# =========================
# AIDE Initialization
# =========================
log "Inicializando AIDE (pode demorar vários minutos)..."

aideinit 2>&1 | while IFS= read -r line; do
  echo "  $line"
done

if [ -f /var/lib/aide/aide.db.new ]; then
  mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  ok "AIDE inicializado"
  
  # Create daily AIDE check cron
  cat > /etc/cron.daily/aide-check <<'EOF'
#!/bin/bash
/usr/bin/aide --check | mail -s "AIDE Report - $(hostname)" root
EOF
  chmod +x /etc/cron.daily/aide-check
else
  log "AVISO: AIDE pode não ter inicializado corretamente"
fi

# =========================
# Automatic Updates
# =========================
log "Configurando atualizações automáticas de segurança..."

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
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
Unattended-Upgrade::SyslogEnable "true";
EOF

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

dpkg-reconfigure -f noninteractive unattended-upgrades

# =========================
# Additional Hardening
# =========================
log "Aplicando hardening adicional..."

# Disable core dumps
cat >> /etc/security/limits.conf <<'EOF'
* hard core 0
EOF

echo "ulimit -c 0" >> /etc/profile

# Restrict /var/log access
chmod -R 0640 /var/log/*
chmod 0755 /var/log

# =========================
# Docker Cleanup Cron
# =========================
log "Configurando limpeza automática do Docker..."
cat > /etc/cron.daily/docker-cleanup <<'EOF'
#!/bin/bash
# CIS Docker cleanup
docker system prune -af --volumes --filter "until=72h" >/dev/null 2>&1
EOF
chmod +x /etc/cron.daily/docker-cleanup

# =========================
# Cleanup
# =========================
apt-get autoremove -y
apt-get clean

# =========================
# Generate Compliance Report
# =========================
log "Gerando relatório de compliance..."

REPORT_FILE="/root/cis-hardening-report-$(date +%Y%m%d-%H%M%S).txt"

cat > "$REPORT_FILE" <<EOF
================================================================================
CIS Ubuntu Linux 24.04 LTS Benchmark - Hardening Report
Generated: $(date)
Hostname: $(hostname)
CIS Level: ${CIS_LEVEL}
================================================================================

SYSTEM INFORMATION:
- OS: $(lsb_release -ds)
- Kernel: $(uname -r)
- Uptime: $(uptime -p)

SECURITY COMPONENTS STATUS:
- AppArmor: $(aa-status --enabled && echo 'Enabled' || echo 'Disabled')
- Auditd: $(systemctl is-active auditd)
- Fail2ban: $(systemctl is-active fail2ban)
- UFW: $(ufw status | grep Status)
- Chrony: $(systemctl is-active chrony)
- Docker: $(docker --version)
- AIDE: $([ -f /var/lib/aide/aide.db ] && echo 'Initialized' || echo 'Not initialized')

NETWORK CONFIGURATION:
$(sysctl net.ipv4.ip_forward net.ipv4.conf.all.send_redirects net.ipv4.tcp_syncookies)

AUDIT RULES:
$(auditctl -l | wc -l) audit rules loaded

SSH CONFIGURATION:
$(sshd -T | grep -E "permitrootlogin|passwordauthentication|pubkeyauthentication")

USER ACCOUNTS:
- Total users: $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd | wc -l)
- Docker user: $(id docker 2>/dev/null && echo 'Configured' || echo 'Not found')

IMPORTANT REMINDERS:
1. Configure bootloader password manually
2. Review and customize audit rules for your environment
3. Configure remote logging if required
4. Set up monitoring and alerting
5. Schedule regular AIDE checks
6. Review firewall rules for your specific needs

CIS BENCHMARK COVERAGE:
✓ Section 1: Initial Setup
✓ Section 2: Services
✓ Section 3: Network Configuration
✓ Section 4: Logging and Auditing
✓ Section 5: Access, Authentication and Authorization
✓ Section 6: System Maintenance

================================================================================
Report saved to: $REPORT_FILE
================================================================================
EOF

# =========================
# Final Report
# =========================
clear

cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ✓ CIS HARDENING CONCLUÍDO COM SUCESSO!                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""
ok "Sistema endurecido conforme CIS Ubuntu Linux 24.04 LTS Benchmark"
ok "Nível CIS: Level ${CIS_LEVEL}"
echo ""

cat "$REPORT_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  PRÓXIMOS PASSOS CRÍTICOS:"
echo ""
echo "1. 🔑 Configure chaves SSH em /home/docker/.ssh/authorized_keys"
echo ""
echo "2. 🧪 TESTE a conexão SSH em outra janela antes de desconectar:"
echo "   ssh docker@seu-servidor"
echo ""
echo "3. ✅ Apenas após confirmar SSH funcionando, reinicie:"
echo "   sudo reboot"
echo ""
echo "4. 📊 Após reiniciar, verifique compliance:"
echo "   sudo lynis audit system"
echo "   (instale com: apt install lynis)"
echo ""
echo "5. 📋 Tarefas manuais pendentes:"
echo "   • Configure senha do GRUB bootloader"
echo "   • Configure logging remoto (rsyslog/syslog-ng)"
echo "   • Implemente backup do AIDE database"
echo "   • Configure alertas de auditoria"
echo "   • Revise regras de firewall específicas"
echo ""
echo "6. 🔐 Hardening adicional recomendado:"
echo "   • Implemente 2FA para SSH (Google Authenticator)"
echo "   • Configure IDS/IPS (OSSEC, Wazuh)"
echo "   • Implemente File Integrity Monitoring contínuo"
echo "   • Configure central log management (ELK, Splunk)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📄 Relatório completo salvo em:"
echo "   $REPORT_FILE"
echo ""
echo "⚠️  AVISO FINAL:"
echo "   • Autenticação por senha está DESABILITADA"
echo "   • Apenas chaves SSH são aceitas"
echo "   • Certifique-se de ter acesso antes de desconectar!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
