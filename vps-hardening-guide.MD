# Guia de Hardening para VPS Compartilhada

## 🎯 Recomendação para Seu Caso

### **MELHOR OPÇÃO: Playbook Ansible Otimizado (hardening-vps-shared.yml)**

**Por quê?**
- ✅ **Leve:** Não sobrecarrega VPS compartilhada
- ✅ **Balanceado:** Segurança + Performance
- ✅ **Idempotente:** Ansible garante consistência
- ✅ **Manutenível:** Fácil de atualizar e versionar
- ✅ **Reversível:** Pode desfazer mudanças facilmente

---

## 📊 Comparação: Script vs Ansible vs CIS Full

| Aspecto | Seu Ansible Atual | Ansible Otimizado | CIS Script Full |
|---------|-------------------|-------------------|-----------------|
| **RECURSOS** |
| Uso de RAM | ~50MB | ~100MB | ~200MB+ |
| Uso de CPU | Baixo | Baixo | Médio-Alto |
| I/O Disco | Baixo | Baixo | **ALTO** ⚠️ |
| Tempo instalação | 3-5 min | 5-8 min | 15-30 min |
| **SEGURANÇA** |
| CIS Score | ~60% | ~75% | ~95% |
| SSH Hardening | ✅ Básico | ✅ Completo | ✅ Completo |
| Firewall | ✅ Básico | ✅ + Docker | ✅ + Docker |
| Auditoria | ⚠️ Lynis only | ✅ Auditd leve | ✅ Auditd pesado |
| AppArmor | ❌ Não | ✅ Sim | ✅ Sim |
| **COMPATIBILIDADE VPS** |
| VPS compartilhada | ✅ Excelente | ✅ Excelente | ⚠️ **Problemático** |
| Kernel hardening | ❌ Não (correto!) | ❌ Não (correto!) | ✅ (pode quebrar!) |
| AIDE | ❌ Não | ❌ Não (correto!) | ✅ (I/O pesado!) |
| **MANUTENÇÃO** |
| Facilidade update | ✅ Fácil | ✅ Fácil | ⚠️ Difícil |
| Idempotência | ✅ Sim | ✅ Sim | ❌ Não |
| Versionamento | ✅ Git | ✅ Git | ⚠️ Manual |
| Rollback | ✅ Fácil | ✅ Fácil | ❌ Difícil |
| **COMPLIANCE** |
| SOC 2 | ⚠️ Parcial | ✅ Básico | ✅ Completo |
| Custo/Benefício | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

---

## ⚠️ Por Que NÃO Usar CIS Full em VPS Compartilhada?

### 1. **AIDE Vai Travar Seu VPS**
```bash
# AIDE faz scan completo do filesystem
# Em VPS compartilhada (I/O limitado):
- Primeiro scan: 30-60 minutos
- Scans diários: 10-30 minutos
- Impacto: VPS fica LENTA para outros clientes
- Resultado: Host pode reclamar ou throttle seu VPS
```

### 2. **Kernel Hardening Pode Quebrar**
```bash
# VPS compartilhada usa kernel do host
# Você NÃO controla o kernel
# Configurações como:
kernel.kptr_restrict=2
kernel.dmesg_restrict=1

# Podem causar:
- Aplicações quebrarem
- Docker ter problemas
- Logs não funcionarem
```

### 3. **Auditd Excessivo = I/O Hell**
```bash
# CIS Level 2 tem 100+ regras audit
# Cada regra = write em disco
# Em VPS com I/O limitado:
- Logs crescem MUITO
- I/O throttling
- Performance degrada
```

### 4. **AppArmor Enforcing All = Quebra Apps**
```bash
# CIS força AppArmor enforcing em TUDO
# Muitas apps não têm profiles
# Resultado: Apps quebram misteriosamente
```

---

## ✅ Por Que o Playbook Otimizado é Melhor?

### 1. **Seletivo e Inteligente**
```yaml
# Você ESCOLHE o que ativar:
enable_aide: false              # ✅ Desliga I/O pesado
enable_kernel_hardening: false  # ✅ Evita problemas com host
enable_auditd_light: true       # ✅ Só eventos críticos
```

### 2. **Otimizado para Docker**
```yaml
# UFW + Docker integrado
# Não quebra networking de containers
# Logs limitados (5MB max)
```

### 3. **Idempotente**
```bash
# Pode executar várias vezes
ansible-playbook hardening-vps-shared.yml

# Sempre chega no mesmo estado
# Sem duplicação de configurações
```

### 4. **Fácil de Customizar**
```yaml
vars:
  vps_ram_mb: 1024        # Ajuste para seu VPS
  ssh_port: 2222          # Mude SSH port facilmente
  f2b_maxretry: 3         # Ajuste fail2ban
  enable_aide: false      # Liga/desliga features
```

---

## 🎚️ Matriz de Decisão

### VPS com 512MB RAM:
```yaml
Recomendação: Playbook Otimizado
Configuração:
  enable_aide: false
  enable_auditd_light: false  # Desliga audit também
  enable_rkhunter: false
  docker_log_size: "3m"
```

### VPS com 1GB RAM:
```yaml
Recomendação: Playbook Otimizado
Configuração:
  enable_aide: false
  enable_auditd_light: true   # Audit leve OK
  docker_log_size: "5m"
```

### VPS com 2GB+ RAM:
```yaml
Recomendação: Playbook Otimizado OU CIS Level 1
Configuração:
  enable_aide: false          # Ainda evite AIDE
  enable_auditd_light: true
  docker_log_size: "10m"
```

### VPS Dedicada (4GB+):
```yaml
Recomendação: CIS Level 1 ou Level 2
Configuração:
  enable_aide: true           # Agora OK
  enable_kernel_hardening: true
  full_audit: true
```

---

## 🚀 Como Usar o Playbook Otimizado

### 1. Preparação

```bash
# No seu computador local
mkdir ~/hardening-vps
cd ~/hardening-vps

# Copiar o playbook
# (arquivo hardening-vps-shared.yml)

# Criar inventory
cat > hosts.ini <<EOF
[vps]
seu-vps.example.com ansible_user=root

[vps:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# Testar conectividade
ansible -i hosts.ini vps -m ping
```

### 2. Customização (IMPORTANTE!)

```yaml
# Edite o playbook antes de executar
nano hardening-vps-shared.yml

# Ajuste conforme seu VPS:
vars:
  vps_ram_mb: 1024           # ← Sua RAM real
  ssh_port: 22               # ← Mude se quiser
  docker_user: deploy        # ← Seu usuário preferido
  
  # Features - ajuste conforme necessidade:
  enable_aide: false              # ✅ Mantenha false em VPS pequena
  enable_auditd_light: true       # ✅ true se >1GB RAM
  enable_rkhunter: false          # ✅ Mantenha false
```

### 3. Dry Run (SEMPRE!)

```bash
# Simular sem executar
ansible-playbook -i hosts.ini hardening-vps-shared.yml --check --diff

# Revisar TODAS as mudanças
# Confirmar que está OK
```

### 4. Executar

```bash
# Executar de verdade
ansible-playbook -i hosts.ini hardening-vps-shared.yml

# Acompanhar output
# Verificar por erros
```

### 5. Validação

```bash
# SSH no servidor
ssh root@seu-vps

# Verificar relatório
cat /root/hardening-report.txt

# Testar serviços
systemctl status ssh
systemctl status ufw
systemctl status fail2ban
systemctl status docker

# Verificar firewall
ufw status verbose

# Testar Docker
docker run hello-world
```

---

## 🔧 Troubleshooting VPS

### Problema: "VPS muito lenta após hardening"

**Diagnóstico:**
```bash
# 1. Verificar I/O
iostat -x 1 5

# 2. Verificar processos pesados
top -o %MEM

# 3. Verificar auditd
auditctl -l | wc -l
# Se > 50, está pesado demais

# 4. Verificar AIDE
ps aux | grep aide
# Se estiver rodando, é o culpado
```

**Solução:**
```bash
# Desabilitar AIDE
systemctl disable aide
systemctl stop aide

# Reduzir audit rules
auditctl -D  # Remove todas
# Re-executar playbook com enable_auditd_light: false
```

### Problema: "Docker sem conectividade"

**Diagnóstico:**
```bash
# Verificar regras UFW
iptables -L DOCKER-USER -n

# Testar container
docker run --rm alpine ping -c 3 google.com
```

**Solução:**
```bash
# Re-aplicar regras UFW+Docker
# Re-executar playbook
```

### Problema: "Lockout SSH"

**Prevenção:**
```bash
# SEMPRE mantenha uma sessão aberta
# SEMPRE teste em nova janela antes de desconectar

# Teste:
ssh -p 22 docker@seu-vps
# Se funcionar, está OK
```

**Solução (se locked out):**
```bash
# Use console do provider (VNC/Serial)
# Ou recovery mode

# Reverter SSH config
mv /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
systemctl restart ssh
```

---

## 📊 Checklist Pré-Hardening VPS

- [ ] **Backup completo** (snapshot do provider)
- [ ] **Chaves SSH testadas** (ssh-copy-id)
- [ ] **Inventário Ansible criado**
- [ ] **Playbook customizado** (vars ajustadas)
- [ ] **Dry-run executado** (--check)
- [ ] **Janela de manutenção** (pode dar problema)
- [ ] **Console do provider acessível** (recovery)
- [ ] **Segunda sessão SSH aberta** (segurança)

---

## 📈 Evolução Gradual Recomendada

### Fase 1: Básico (Semana 1)
```yaml
enable_docker_hardening: true
enable_auditd_light: false
enable_aide: false
```

### Fase 2: Intermediário (Semana 2-3)
```yaml
enable_auditd_light: true   # Adicionar audit leve
# Monitorar performance
```

### Fase 3: Avançado (Se performance OK)
```yaml
# Considerar CIS Level 1
# Ou adicionar features extras
```

---

## 💡 Dicas Extras para VPS Compartilhada

### 1. Monitoramento Leve
```bash
# Use ferramentas leves
apt install htop iotop

# Evite:
- Prometheus (pesado demais)
- ELK Stack (impossível em VPS pequena)
- Grafana (muita RAM)

# Prefira:
- Netdata (leve e eficiente)
- Uptime Kuma (para external monitoring)
```

### 2. Logs Controlados
```bash
# Rotação agressiva
logrotate -f /etc/logrotate.conf

# Limitar tamanho de logs
journalctl --vacuum-size=100M
```

### 3. Docker Otimizado
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "5m",    // Pequeno!
    "max-file": "2"      // Poucos arquivos!
  }
}
```

---

## 🎯 Conclusão

### Para VPS Compartilhada Pequena (≤2GB):
**✅ USE: Playbook Ansible Otimizado**

**❌ NÃO USE: CIS Script Full**

### Exceções:
- VPS dedicada (4GB+): CIS Level 1 OK
- Servidor bare metal: CIS Level 2 OK
- Production crítica: CIS Level 2 + extras

---

## 📚 Recursos Adicionais

### Scripts Úteis para VPS

```bash
# 1. Script de diagnóstico rápido
#!/bin/bash
echo "=== VPS Health Check ==="
echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2}')"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Docker: $(docker ps -q | wc -l) containers"
echo "UFW: $(ufw status | grep -c active) active"
```

```bash
# 2. Script de limpeza emergencial
#!/bin/bash
docker system prune -af --volumes
apt-get clean
apt-get autoremove -y
journalctl --vacuum-size=50M
find /var/log -type f -name "*.gz" -delete
```

---

**Última atualização:** Janeiro 2026  
**Versão:** 1.0.0  
**Compatibilidade:** Ubuntu 22.04+, VPS 512MB-2GB
