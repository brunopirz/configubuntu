#!/bin/bash
# CIS Ubuntu 24.04 LTS Benchmark Validation Script
# Verifica conformidade com CIS Level 1 e 2

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
  local title="$1"
  local command="$2"
  local expected="$3"
  
  if eval "$command" &>/dev/null; then
    result=$(eval "$command" 2>/dev/null || echo "")
    if [[ "$result" == *"$expected"* ]] || [[ -z "$expected" ]]; then
      echo -e "${GREEN}✓${NC} $title"
      ((PASS++))
      return 0
    fi
  fi
  
  echo -e "${RED}✗${NC} $title"
  ((FAIL++))
  return 1
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  ((WARN++))
}

section() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════${NC}"
}

echo "CIS Ubuntu 24.04 LTS Benchmark Compliance Check"
echo "Started: $(date)"
echo ""

# 1. Initial Setup
section "1. INITIAL SETUP"

check "1.1.1 Bootloader config protected" \
  "stat -L -c '%a' /boot/grub/grub.cfg 2>/dev/null" \
  "600"

check "1.3.1 AIDE installed" \
  "dpkg -s aide" \
  "install ok installed"

check "1.4.1 Bootloader password set" \
  "grep -E '^set superusers' /boot/grub/grub.cfg" \
  "superusers" || warn "Configure GRUB password manually"

check "1.5.1 AppArmor enabled" \
  "aa-status --enabled" \
  ""

check "1.5.2 All AppArmor profiles enforced" \
  "aa-status" \
  "enforce"

# 2. Services
section "2. SERVICES"

check "2.1.1 Time synchronization (chrony)" \
  "systemctl is-active chrony" \
  "active"

check "2.2.1 Avahi daemon disabled" \
  "systemctl is-enabled avahi-daemon 2>/dev/null || echo disabled" \
  "disabled"

check "2.2.2 CUPS disabled" \
  "systemctl is-enabled cups 2>/dev/null || echo disabled" \
  "disabled"

check "2.2.3 DHCP server disabled" \
  "systemctl is-enabled isc-dhcp-server 2>/dev/null || echo disabled" \
  "disabled"

check "2.2.4 LDAP server disabled" \
  "systemctl is-enabled slapd 2>/dev/null || echo disabled" \
  "disabled"

check "2.2.5 NFS disabled" \
  "systemctl is-enabled nfs-server 2>/dev/null || echo disabled" \
  "disabled"

check "2.2.6 RPC disabled" \
  "systemctl is-enabled rpcbind 2>/dev/null || echo disabled" \
  "disabled"

# 3. Network Configuration
section "3. NETWORK CONFIGURATION"

check "3.1.1 IP forwarding" \
  "sysctl net.ipv4.ip_forward" \
  "net.ipv4.ip_forward = 1"

check "3.2.1 Source routed packets not accepted" \
  "sysctl net.ipv4.conf.all.accept_source_route" \
  "= 0"

check "3.2.2 ICMP redirects not accepted" \
  "sysctl net.ipv4.conf.all.accept_redirects" \
  "= 0"

check "3.2.3 Secure ICMP redirects not accepted" \
  "sysctl net.ipv4.conf.all.secure_redirects" \
  "= 0"

check "3.2.4 Suspicious packets logged" \
  "sysctl net.ipv4.conf.all.log_martians" \
  "martians"

check "3.2.5 Broadcast ICMP ignored" \
  "sysctl net.ipv4.icmp_echo_ignore_broadcasts" \
  "= 1"

check "3.2.6 TCP SYN Cookies enabled" \
  "sysctl net.ipv4.tcp_syncookies" \
  "= 1"

check "3.2.7 Reverse path filtering" \
  "sysctl net.ipv4.conf.all.rp_filter" \
  "= 1"

check "3.2.8 IPv6 router advertisements" \
  "sysctl net.ipv6.conf.all.accept_ra" \
  "= 0"

# 4. Logging and Auditing
section "4. LOGGING AND AUDITING"

check "4.1.1 Auditd installed" \
  "dpkg -s auditd" \
  "install ok installed"

check "4.1.2 Auditd enabled" \
  "systemctl is-enabled auditd" \
  "enabled"

check "4.1.3 Audit rules loaded" \
  "auditctl -l | wc -l" \
  ""

if [ $(auditctl -l | wc -l) -gt 10 ]; then
  echo -e "${GREEN}✓${NC} Audit rules loaded ($(auditctl -l | wc -l) rules)"
  ((PASS++))
else
  echo -e "${RED}✗${NC} Insufficient audit rules"
  ((FAIL++))
fi

check "4.2.1 rsyslog installed" \
  "dpkg -s rsyslog" \
  "install ok installed"

check "4.2.2 rsyslog enabled" \
  "systemctl is-enabled rsyslog" \
  "enabled"

# 5. Access, Authentication and Authorization
section "5. ACCESS, AUTHENTICATION AND AUTHORIZATION"

check "5.1.1 cron enabled" \
  "systemctl is-enabled cron" \
  "enabled"

check "5.1.2 cron permissions" \
  "stat -L -c '%a' /etc/crontab" \
  "600"

check "5.2.1 SSH config permissions" \
  "stat -L -c '%a' /etc/ssh/sshd_config" \
  "600"

check "5.2.4 SSH access limited" \
  "sshd -T | grep -E 'allowusers|allowgroups'" \
  ""

check "5.2.5 SSH LogLevel" \
  "sshd -T | grep loglevel" \
  "VERBOSE"

check "5.2.6 SSH PAM enabled" \
  "sshd -T | grep usepam" \
  "yes"

check "5.2.7 SSH root login" \
  "sshd -T | grep permitrootlogin" \
  "prohibit-password"

check "5.2.8 SSH HostbasedAuthentication" \
  "sshd -T | grep hostbasedauthentication" \
  "no"

check "5.2.9 SSH PermitEmptyPasswords" \
  "sshd -T | grep permitemptypasswords" \
  "no"

check "5.2.10 SSH PermitUserEnvironment" \
  "sshd -T | grep permituserenvironment" \
  "no"

check "5.2.11 SSH IgnoreRhosts" \
  "sshd -T | grep ignorerhosts" \
  "yes"

check "5.2.12 SSH X11Forwarding" \
  "sshd -T | grep x11forwarding" \
  "no"

check "5.2.13 SSH MaxAuthTries" \
  "sshd -T | grep maxauthtries" \
  ""

check "5.2.14 SSH LoginGraceTime" \
  "sshd -T | grep logingracetime" \
  ""

check "5.2.15 SSH ClientAliveInterval" \
  "sshd -T | grep clientaliveinterval" \
  "300"

check "5.2.16 SSH Banner" \
  "sshd -T | grep banner" \
  "/etc/issue.net"

check "5.2.17 Password authentication disabled" \
  "sshd -T | grep passwordauthentication" \
  "no"

check "5.3.1 sudo installed" \
  "dpkg -s sudo" \
  "install ok installed"

check "5.3.2 sudo log file" \
  "grep -E 'Defaults\\s+logfile=' /etc/sudoers /etc/sudoers.d/*" \
  "logfile"

check "5.4.1 Password quality" \
  "grep -E '^minlen' /etc/security/pwquality.conf" \
  "minlen"

check "5.4.2 Account lockout (faillock)" \
  "grep -E '^deny' /etc/security/faillock.conf" \
  "deny"

check "5.5.1 Password max days" \
  "grep PASS_MAX_DAYS /etc/login.defs" \
  "90"

check "5.5.2 Password min days" \
  "grep PASS_MIN_DAYS /etc/login.defs" \
  "1"

check "5.5.3 Password warn age" \
  "grep PASS_WARN_AGE /etc/login.defs" \
  "7"

check "5.5.4 Default umask" \
  "grep -E '^UMASK' /etc/login.defs" \
  "027"

# 6. System Maintenance
section "6. SYSTEM MAINTENANCE"

check "6.1.1 /etc/passwd permissions" \
  "stat -L -c '%a' /etc/passwd" \
  "644"

check "6.1.2 /etc/shadow permissions" \
  "stat -L -c '%a' /etc/shadow" \
  "640"

check "6.1.3 /etc/group permissions" \
  "stat -L -c '%a' /etc/group" \
  "644"

check "6.1.4 /etc/gshadow permissions" \
  "stat -L -c '%a' /etc/gshadow" \
  "640"

# Additional Security Checks
section "ADDITIONAL SECURITY CHECKS"

check "AppArmor status" \
  "aa-status --enabled" \
  ""

check "UFW enabled" \
  "ufw status | grep Status" \
  "active"

check "fail2ban active" \
  "systemctl is-active fail2ban" \
  "active"

check "Docker installed" \
  "docker --version" \
  ""

check "Unattended upgrades configured" \
  "dpkg -s unattended-upgrades" \
  "install ok installed"

# Kernel hardening
check "ASLR enabled" \
  "sysctl kernel.randomize_va_space" \
  "= 2"

check "Core dumps disabled" \
  "sysctl fs.suid_dumpable" \
  "= 0"

check "Kernel pointer restriction" \
  "sysctl kernel.kptr_restrict" \
  "= 2"

# Summary
section "COMPLIANCE SUMMARY"

TOTAL=$((PASS + FAIL + WARN))
PERCENTAGE=$(( (PASS * 100) / TOTAL ))

echo ""
echo "Total Checks: $TOTAL"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo -e "${YELLOW}Warnings: $WARN${NC}"
echo ""
echo "Compliance Score: ${PERCENTAGE}%"
echo ""

if [ $PERCENTAGE -ge 90 ]; then
  echo -e "${GREEN}✓ EXCELLENT - Sistema altamente seguro${NC}"
elif [ $PERCENTAGE -ge 75 ]; then
  echo -e "${YELLOW}⚠ GOOD - Algumas melhorias necessárias${NC}"
else
  echo -e "${RED}✗ NEEDS IMPROVEMENT - Ação imediata necessária${NC}"
fi

echo ""
echo "Recommendations:"
echo "1. Review all failed checks above"
echo "2. Address critical security issues first"
echo "3. Run 'sudo lynis audit system' for detailed analysis"
echo "4. Schedule regular compliance audits"
echo "5. Keep system and packages updated"
echo ""
echo "Report generated: $(date)"
