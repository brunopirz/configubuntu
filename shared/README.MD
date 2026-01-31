# VPS Hardening - Versão Lite Híbrida

> 🔒 Hardening otimizado para VPS compartilhada com Docker
> 
> ✅ Segurança robusta  
> ✅ Leve e rápido  
> ✅ Suporta autenticação por senha (protegida)

## 🎯 Para quem é este script?

- ✅ VPS compartilhada (2-4 vCPU, 2-8GB RAM)
- ✅ Ambientes de desenvolvimento e testes
- ✅ Precisa de acesso via senha em múltiplos computadores
- ✅ Usa Docker para aplicações
- ✅ Quer segurança sem complexidade

## ⚡ Instalação Rápida (5 minutos)

### Opção 1: Script Bash (mais simples)

```bash
# 1. Conectar como root
ssh root@seu-servidor

# 2. Baixar script
wget https://raw.githubusercontent.com/SEU-REPO/vps-hardening-lite.sh
chmod +x vps-hardening-lite.sh

# 3. Executar
./vps-hardening-lite.sh

# 4. Definir senha para usuário docker
passwd docker

# 5. TESTAR em outra janela (NÃO FECHE A ATUAL!)
ssh docker@seu-servidor

# 6. Se funcionar, reinicie
reboot
```

### Opção 2: Ansible (múltiplos servidores)

```bash
# 1. Instalar Ansible localmente
sudo apt install ansible

# 2. Criar inventário
cat > hosts.ini <<EOF
[vps]
meu-servidor ansible_host=IP_DO_SERVIDOR ansible_user=root
EOF

# 3. Executar
ansible-playbook -i hosts.ini vps-hardening-lite.yml

# 4. Definir senha
ssh root@seu-servidor
passwd docker
```

## 🛡️ O que este script faz?

### ✅ Segurança

- **SSH Hardening**: Proteção contra brute-force
- **Firewall**: UFW configurado + integração Docker
- **fail2ban**: Bane IPs após 3 tentativas falhas
- **AppArmor**: Proteção de containers
- **Atualizações automáticas**: Patches de segurança
- **Kernel hardening**: Parâmetros otimizados

### 🚀 Performance

- **Leve**: ~600MB RAM durante operação
- **Rápido**: Instalação em 8-12 minutos
- **Otimizado**: Docker com logs limitados
- **Limpeza automática**: Semanal

### 🎛️ Configurações

- **Docker**: Instalado e otimizado
- **Usuário docker**: Criado com permissões adequadas
- **Chrony**: Sincronização de tempo
- **Logs**: Rotação automática

## 📊 Antes vs Depois

| Métrica | Antes | Depois |
|---------|-------|--------|
| Processos | ~80 | ~95 |
| RAM usado | ~200MB | ~500MB |
| Disco usado | ~1.5GB | ~3.5GB |
| Segurança | ⚠️ Básica | ✅ Robusta |
| Manutenção | Manual | Automática |

## 🔐 Segurança com Senha

Este script permite autenticação por senha (diferente dos originais), mas com proteções:

- ✅ fail2ban configurado AGRESSIVAMENTE (3 tentativas = ban de 1h)
- ✅ Logs detalhados em `/var/log/auth.log`
- ✅ Root só aceita chave SSH
- ✅ MaxAuthTries = 3
- ✅ Proteção contra SSH DDOS

**Recomendação:** Use senha FORTE (16+ caracteres)

## 🎯 Próximos Passos Após Instalação

1. **Defina senha forte:**
   ```bash
   passwd docker
   ```

2. **TESTE SSH antes de desconectar:**
   ```bash
   ssh docker@seu-servidor
   ```

3. **Verifique serviços:**
   ```bash
   systemctl status docker fail2ban ufw chrony
   ```

4. **Monitore logs:**
   ```bash
   tail -f /var/log/auth.log
   fail2ban-client status sshd
   ```

5. **Configure backup externo**

## 🔧 Personalização

### Desabilitar senha depois (migrar para chave SSH):

```bash
# 1. Adicionar sua chave SSH
ssh-copy-id docker@seu-servidor

# 2. Testar
ssh docker@seu-servidor

# 3. Desabilitar senha
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl reload ssh
```

### Mudar porta SSH:

```bash
# Editar configuração
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
# Mudar: Port 22 -> Port 2222

# Atualizar firewall
sudo ufw allow 2222/tcp
sudo ufw delete allow OpenSSH

# Reiniciar SSH
sudo systemctl reload ssh
```

### fail2ban mais agressivo:

```bash
sudo nano /etc/fail2ban/jail.local
# Mudar:
# maxretry = 2    (apenas 2 tentativas)
# bantime = 7200  (ban de 2 horas)

sudo systemctl restart fail2ban
```

## 📝 Arquivos Importantes

- `/root/hardening-report.txt` - Relatório completo
- `/var/log/auth.log` - Logs de autenticação
- `/etc/ssh/sshd_config.d/99-hardening.conf` - Config SSH
- `/etc/fail2ban/jail.local` - Config fail2ban
- `/etc/docker/daemon.json` - Config Docker

## 🆘 Problemas Comuns

### SSH não conecta

```bash
# Ver logs
tail -50 /var/log/auth.log

# Verificar serviço
systemctl status ssh

# Seu IP foi banido?
fail2ban-client status sshd
fail2ban-client set sshd unbanip SEU_IP
```

### Docker não funciona

```bash
systemctl status docker
journalctl -u docker -n 50
systemctl restart docker
```

### Esqueci a senha

```bash
# Conecte como root (com chave SSH)
ssh root@seu-servidor
passwd docker
```

## 📚 Documentação Completa

Veja `GUIA-COMPLETO.md` para:
- Comparação detalhada com scripts originais
- Tabela completa de recursos
- Guia de troubleshooting
- Referências e boas práticas

## ⚠️ Avisos Importantes

1. **SEMPRE teste SSH em outra janela antes de desconectar**
2. **Use senha FORTE** se manter autenticação por senha
3. **Configure backup externo** - este script não faz backup
4. **Monitore logs regularmente**
5. **Mantenha o sistema atualizado**

## 🤝 Contribuindo

Encontrou um bug? Tem uma sugestão?

1. Abra uma issue
2. Fork e faça um PR
3. Compartilhe sua experiência

## 📄 Licença

MIT License - Use como quiser!

## 🙏 Créditos

Baseado em:
- [rameerez/docker-host-hardening](https://gist.github.com/rameerez/238927b78f9108a71a77aed34208de11)
- CIS Ubuntu 22.04 Benchmark
- Docker Security Best Practices

---

**Versão:** 1.0.0  
**Última atualização:** Janeiro 2026  
**Compatibilidade:** Ubuntu 22.04+  
**Testado em:** DigitalOcean, Linode, Hetzner, Contabo

---

## 🚀 Comece Agora!

```bash
wget https://raw.githubusercontent.com/SEU-REPO/vps-hardening-lite.sh
chmod +x vps-hardening-lite.sh
sudo ./vps-hardening-lite.sh
```

**Tempo estimado:** 10 minutos  
**Resultado:** VPS segura e otimizada 🔒
