# Guia de Hardening CIS para Ubuntu Server 24.04 LTS

## 📋 Índice

1. [Introdução](#introdução)
2. [O que é CIS Benchmark](#o-que-é-cis-benchmark)
3. [Diferenças entre Level 1 e Level 2](#diferenças-entre-levels)
4. [Pré-requisitos](#pré-requisitos)
5. [Instalação](#instalação)
6. [Verificação de Compliance](#verificação)
7. [Tarefas Pós-Instalação](#tarefas-pós-instalação)
8. [Troubleshooting](#troubleshooting)
9. [Referências](#referências)

---

## 🎯 Introdução

Este guia implementa o **CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0** para hardening de servidores Ubuntu com foco em ambientes Docker.

### O que será configurado?

- ✅ Hardening de kernel e rede
- ✅ Auditoria completa do sistema (auditd)
- ✅ Controle de acesso e autenticação
- ✅ Firewall (UFW) com integração Docker
- ✅ Proteção contra brute-force (fail2ban)
- ✅ Verificação de integridade de arquivos (AIDE)
- ✅ Logging centralizado e rotação
- ✅ AppArmor em modo enforcing
- ✅ Docker com configurações de segurança

---

## 📚 O que é CIS Benchmark?

O **Center for Internet Security (CIS)** é uma organização sem fins lucrativos que desenvolve padrões de segurança reconhecidos globalmente.

### Por que CIS?

- 🏆 Padrão da indústria para compliance
- 🔒 Recomendado por frameworks como NIST, PCI-DSS, HIPAA
- 📊 Usado em auditorias de segurança
- 🌍 Aceito mundialmente por organizações governamentais e privadas

### Certificações e Compliance

Implementar CIS Benchmarks ajuda a atender requisitos de:

- **SOC 2** - Service Organization Control
- **ISO 27001** - Information Security Management
- **PCI-DSS** - Payment Card Industry Data Security Standard
- **HIPAA** - Health Insurance Portability and Accountability Act
- **GDPR** - General Data Protection Regulation
- **LGPD** - Lei Geral de Proteção de Dados

---

## 🎚️ Diferenças entre Levels

### CIS Level 1 (Básico - Produção)

**Objetivo:** Configurações essenciais de segurança sem impacto significativo na funcionalidade.

✅ **Recomendado para:**
- Servidores de produção
- Ambientes corporativos padrão
- Sistemas que precisam de boa usabilidade

**Implementa:**
- Desabilitação de serviços desnecessários
- Configuração básica de firewall
- SSH endurecido (mas funcional)
- Auditoria básica
- Políticas de senha
- Atualizações automáticas de segurança

**Impacto:** ⚠️ Baixo - Sistema permanece totalmente funcional

---

### CIS Level 2 (Avançado - Alta Segurança)

**Objetivo:** Segurança máxima, pode impactar funcionalidade e usabilidade.

✅ **Recomendado para:**
- Sistemas com dados sensíveis
- Ambientes regulados (PCI, HIPAA)
- Infraestrutura crítica
- Sistemas que processam informações confidenciais

**Implementa tudo do Level 1, MAIS:**
- Hardening agressivo de kernel
- Restrições adicionais de rede
- AppArmor em modo enforcing para todos os serviços
- Auditoria extensiva de todas as ações
- Políticas de senha mais rigorosas
- Timeouts agressivos
- Logging detalhado de tudo

**Impacto:** ⚠️⚠️ Moderado a Alto - Pode afetar algumas funcionalidades

---

## 🔧 Pré-requisitos

### Requisitos de Sistema

```bash
- Ubuntu Server 22.04 LTS ou superior
- Mínimo 1GB RAM
- Mínimo 10GB disco livre
- Acesso root
- Conexão com internet
```

### Requisitos de Acesso

⚠️ **CRÍTICO - Leia com atenção:**

1. **Chave SSH configurada** - Senha será desabilitada!
2. **Acesso físico ou console** - Em caso de lockout
3. **Backup recente** - Sempre tenha um backup antes de hardening
4. **Janela de manutenção** - O sistema será reiniciado

### Antes de Começar

```bash
# 1. Copie sua chave SSH pública para o servidor
ssh-copy-id root@seu-servidor

# 2. Teste a conexão
ssh root@seu-servidor

# 3. Faça backup (se possível)
# Exemplo com snapshot em cloud provider:
# AWS: aws ec2 create-snapshot
# GCP: gcloud compute disks snapshot
# Azure: az snapshot create

# 4. Crie um snapshot/backup manual se necessário
tar -czf /root/backup-$(date +%F).tar.gz /etc /home
```

---

## 🚀 Instalação

### Método 1: Download e Execução Direta

```bash
# 1. Baixar o script
curl -fsSL https://raw.githubusercontent.com/seu-repo/cis-hardening.sh -o cis-hardening.sh

# 2. Revisar o script (SEMPRE!)
less cis-hardening.sh

# 3. Tornar executável
chmod +x cis-hardening.sh

# 4. Executar como root
sudo ./cis-hardening.sh
```

### Método 2: Execução com Nível Específico

```bash
# Level 1 (padrão, recomendado para produção)
sudo CIS_LEVEL=1 ./cis-hardening.sh

# Level 2 (alta segurança)
sudo CIS_LEVEL=2 ./cis-hardening.sh
```

### Método 3: Teste em Docker (Recomendado para Testes)

```bash
# Criar container de teste
docker run -it --privileged ubuntu:24.04 bash

# Dentro do container
apt update
apt install -y curl
curl -fsSL URL_DO_SCRIPT | bash
```

---

## ✅ Verificação de Compliance

Após a instalação, valide a conformidade:

### Script de Validação Automática

```bash
# 1. Tornar executável
chmod +x cis-validation.sh

# 2. Executar validação
sudo ./cis-validation.sh

# 3. Verificar score
# Alvo: > 90% para produção
# Alvo: > 95% para ambientes críticos
```

### Ferramentas Adicionais

#### Lynis (Recomendado)

```bash
# Instalar
sudo apt install lynis

# Executar auditoria completa
sudo lynis audit system

# Gerar relatório
sudo lynis audit system --auditor "Seu Nome" --pentest

# Verificar score
# O Lynis atribui um "hardening index"
# Alvo: > 80 para produção
```

#### OpenSCAP

```bash
# Instalar
sudo apt install libopenscap8 ssg-base ssg-debian

# Executar scan CIS
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results results.xml \
  --report report.html \
  /usr/share/xml/scap/ssg/content/ssg-ubuntu2404-ds.xml
```

---

## 📝 Tarefas Pós-Instalação

### 1. Configurar Chaves SSH (OBRIGATÓRIO)

```bash
# Como usuário docker
mkdir -p /home/docker/.ssh
chmod 700 /home/docker/.ssh

# Adicionar sua chave pública
echo "sua-chave-publica-aqui" >> /home/docker/.ssh/authorized_keys
chmod 600 /home/docker/.ssh/authorized_keys
chown -R docker:docker /home/docker/.ssh

# TESTAR em outra janela antes de desconectar!
ssh docker@seu-servidor
```

### 2. Configurar Senha do GRUB (CIS 1.4.1)

```bash
# Gerar hash de senha
grub-mkpasswd-pbkdf2

# Editar configuração
sudo nano /etc/grub.d/40_custom

# Adicionar:
set superusers="admin"
password_pbkdf2 admin HASH_GERADO_ACIMA

# Atualizar GRUB
sudo update-grub
```

### 3. Configurar Logging Remoto (Recomendado)

```bash
# Exemplo com rsyslog para servidor central
sudo nano /etc/rsyslog.d/50-remote.conf

# Adicionar:
*.* @@log-server.example.com:514

# Reiniciar
sudo systemctl restart rsyslog
```

### 4. Configurar Alertas AIDE

```bash
# Criar script de alerta
sudo nano /usr/local/bin/aide-alert.sh

#!/bin/bash
REPORT=$(aide --check)
if [ $? -ne 0 ]; then
  echo "$REPORT" | mail -s "AIDE Alert - $(hostname)" admin@example.com
fi

# Agendar verificação diária
sudo crontab -e
0 2 * * * /usr/local/bin/aide-alert.sh
```

### 5. Configurar Monitoramento

Exemplos de ferramentas:

```bash
# Prometheus Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter

# Systemd service
sudo nano /etc/systemd/system/node_exporter.service
# ... configurar service ...

sudo systemctl enable node_exporter --now
```

### 6. Backup do AIDE Database

```bash
# Criar backup
sudo cp /var/lib/aide/aide.db /root/aide.db.backup

# Ou automatizar
cat > /etc/cron.weekly/aide-backup <<'EOF'
#!/bin/bash
cp /var/lib/aide/aide.db /root/aide-backup-$(date +%F).db
find /root/aide-backup-* -mtime +30 -delete
EOF

chmod +x /etc/cron.weekly/aide-backup
```

---

## 🔥 Troubleshooting

### Problema 1: Não Consigo Conectar via SSH

**Sintomas:** `Permission denied (publickey)`

**Solução:**
```bash
# 1. Conectar via console (necessário!)
# 2. Verificar configuração SSH
sudo sshd -T | grep -i password
sudo sshd -T | grep -i pubkey

# 3. Verificar chaves
ls -la /home/docker/.ssh/

# 4. Verificar permissões
sudo chmod 700 /home/docker/.ssh
sudo chmod 600 /home/docker/.ssh/authorized_keys
sudo chown -R docker:docker /home/docker/.ssh

# 5. Verificar logs
sudo tail -f /var/log/auth.log

# 6. Temporariamente habilitar senha (EMERGÊNCIA)
sudo nano /etc/ssh/sshd_config.d/99-emergency.conf
# Adicionar: PasswordAuthentication yes
sudo systemctl restart sshd
```

### Problema 2: Docker Containers Sem Rede

**Sintomas:** Containers não acessam internet

**Solução:**
```bash
# 1. Verificar UFW
sudo ufw status verbose

# 2. Verificar regras Docker
sudo iptables -L DOCKER-USER -n

# 3. Recriar regras UFW+Docker
sudo nano /etc/ufw/after.rules
# ... adicionar regras Docker ...

sudo ufw reload
```

### Problema 3: Sistema Muito Lento

**Sintomas:** Alta carga de CPU/Disco

**Solução:**
```bash
# 1. Verificar AIDE (pode estar rodando)
ps aux | grep aide

# 2. Verificar auditd
auditctl -l | wc -l
# Se > 200 regras, considere reduzir

# 3. Desabilitar regras audit temporariamente
sudo auditctl -D  # Remove todas as regras
# Depois recarregar: sudo augenrules --load

# 4. Verificar logs
du -sh /var/log/*
# Limpar se necessário
```

### Problema 4: Auditd Consumindo Muito Espaço

**Solução:**
```bash
# Configurar rotação mais agressiva
sudo nano /etc/audit/auditd.conf

# Modificar:
max_log_file = 50
num_logs = 5
max_log_file_action = ROTATE

sudo systemctl restart auditd
```

### Problema 5: AIDE Muito Lento

**Solução:**
```bash
# Excluir diretórios dinâmicos
sudo nano /etc/aide/aide.conf

# Adicionar exclusões:
!/var/lib/docker
!/var/log
!/tmp
!/proc
!/sys

# Reinicializar database
sudo aideinit
```

---

## 📊 Checklist de Hardening

Use esta lista para verificar manualmente:

### Antes da Instalação
- [ ] Backup completo realizado
- [ ] Chaves SSH configuradas e testadas
- [ ] Acesso ao console disponível
- [ ] Janela de manutenção agendada
- [ ] Stakeholders notificados

### Durante a Instalação
- [ ] Script revisado
- [ ] Nível CIS escolhido (1 ou 2)
- [ ] Instalação monitorada
- [ ] Erros documentados

### Após a Instalação
- [ ] SSH funcional como usuário docker
- [ ] SSH funcional como root (emergency)
- [ ] Firewall configurado corretamente
- [ ] Docker funcionando
- [ ] Containers com rede
- [ ] AIDE inicializado
- [ ] Auditd rodando
- [ ] fail2ban ativo
- [ ] Logs rotacionando
- [ ] Sistema reiniciado
- [ ] Todos os serviços ativos após reboot

### Hardening Adicional
- [ ] Senha GRUB configurada
- [ ] Logging remoto configurado
- [ ] Monitoramento configurado
- [ ] Alertas AIDE configurados
- [ ] Backup AIDE database
- [ ] 2FA implementado (opcional)
- [ ] IDS/IPS configurado (opcional)

### Validação Final
- [ ] cis-validation.sh executado (> 90%)
- [ ] lynis audit system executado (> 80)
- [ ] OpenSCAP scan executado
- [ ] Vulnerabilidades corrigidas
- [ ] Documentação atualizada
- [ ] Runbook criado

---

## 🔐 Hardening Adicional Recomendado

### 1. Implementar 2FA para SSH

```bash
# Instalar Google Authenticator
sudo apt install libpam-google-authenticator

# Configurar para usuário
su - docker
google-authenticator
# Responder: yes, yes, yes, no, yes

# Configurar PAM
sudo nano /etc/pam.d/sshd
# Adicionar no topo:
auth required pam_google_authenticator.so

# Configurar SSH
sudo nano /etc/ssh/sshd_config.d/99-2fa.conf
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive

sudo systemctl restart sshd
```

### 2. Implementar IDS (OSSEC/Wazuh)

```bash
# Instalar Wazuh Agent
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt update
sudo apt install wazuh-agent

# Configurar manager
sudo nano /var/ossec/etc/ossec.conf
# ... adicionar IP do Wazuh Manager ...

sudo systemctl enable wazuh-agent --now
```

### 3. Kernel Hardening Avançado

```bash
# Criar configuração adicional
sudo nano /etc/sysctl.d/99-extreme-hardening.conf

# Adicionar:
# Disable all SysRq functions
kernel.sysrq = 0

# Restrict dmesg
kernel.dmesg_restrict = 1

# Restrict kernel logs
kernel.printk = 3 3 3 3

# Disable kexec (prevents kernel replacement)
kernel.kexec_load_disabled = 1

# Harden memory
vm.mmap_min_addr = 65536

# Apply
sudo sysctl --system
```

---

## 📖 Referências

### Documentação Oficial

- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [Ubuntu Security](https://ubuntu.com/security)
- [Docker Security](https://docs.docker.com/engine/security/)

### Ferramentas de Auditoria

- [Lynis](https://cisofy.com/lynis/)
- [OpenSCAP](https://www.open-scap.org/)
- [Docker Bench Security](https://github.com/docker/docker-bench-security)

### Guias Complementares

- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Docker Security](https://github.com/OWASP/Docker-Security)
- [Linux Hardening Guide](https://www.debian.org/doc/manuals/securing-debian-manual/)

### Compliance Frameworks

- [SOC 2](https://www.aicpa.org/soc)
- [ISO 27001](https://www.iso.org/isoiec-27001-information-security.html)
- [PCI-DSS](https://www.pcisecuritystandards.org/)

---

## 🆘 Suporte

### Em Caso de Problemas

1. **Revise os logs:**
   ```bash
   sudo journalctl -xe
   sudo tail -f /var/log/syslog
   sudo tail -f /var/log/auth.log
   ```

2. **Execute validação:**
   ```bash
   sudo ./cis-validation.sh
   ```

3. **Consulte documentação CIS oficial**

4. **Entre em contato com a equipe de segurança**

---

## 📄 Licença

Este script é fornecido "como está", sem garantias. Use por sua própria conta e risco.

**Recomendação:** Sempre teste em ambiente de desenvolvimento antes de produção.

---

## ✍️ Contribuindo

Melhorias e correções são bem-vindas! Por favor:

1. Teste suas mudanças
2. Documente alterações
3. Siga as diretrizes CIS
4. Submeta pull request

---

**Última atualização:** Janeiro 2026  
**Versão:** 1.0.0  
**CIS Benchmark:** Ubuntu Linux 24.04 LTS v1.0.0
