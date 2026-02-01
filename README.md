# Ubuntu Hardening – Ansible 24.04+

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

Uma ferramenta de configuração pós-instalação para servidores Ubuntu, simplificando o processo de configuração e implementando as melhores práticas de segurança Dev Sec Ops.

## 🚀 Funcionalidades

- Configuração automatizada pós-instalação
- Configurações de segurança aprimoradas
- Configuração de softwares comuns para servidor
- Otimizações de desempenho

## 📋 Requisitos

- Ubuntu Server (24.04)
- Acesso root ou sudo
- Conhecimentos avançados de Kernel

## 💡 Uso

Execute o script de configuração no seu servidor para bloquear sudo e criar usuário docker sem privilégios:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/brunopirz/configubuntu/refs/heads/main/boot.sh)
```
ou para permitir sudo em usuário docker 

```bash
bash <(curl -sSL https://raw.githubusercontent.com/brunopirz/configubuntu/refs/heads/main/shared/vps-hardening-revised.sh)
```
Após a instalação a conexão será feita com o usuário: docker

ex: docker@ip:senha_original

## 🐋 Criando o Docker Swarm

Execute os seguintes comandos:

```bash
docker swarm init --advertise-addr="<ip público da sua vps>"
docker network create --driver=overlay network_public
```
PS: Pode substituir o "network_public" pelo nome da rede q preferir

# Ubuntu Hardening – Ansible

Este repositório contém playbooks Ansible para hardening de servidores Ubuntu 22.04+ seguindo CIS Benchmark e boas práticas DevSecOps.

---

## Estrutura

* `hardening_shared.yml` → VPS compartilhada / desenvolvimento
* `hardening_production.yml` → Produção / servidor dedicado
* `Ansible Full Hardening – CIS L1+L2 DevSecOps` → Documento arquitetural

---

## Quando usar cada playbook

### hardening_shared.yml

Use quando:

* VPS compartilhada
* Ambiente de desenvolvimento
* Provedor não permite alterações profundas de kernel

Características:

* CIS Level 1
* Hardening seguro
* Baixo risco de lockout

---

### hardening_production.yml

Use quando:

* Servidor dedicado
* Cloud VM isolada
* Ambiente de produção

Características:

* CIS Level 1 + 2
* Kernel hardening
* Docker hardening
* Auditoria ativa

---

## Execução

```bash
ansible-playbook -i inventory hardening_shared.yml
ansible-playbook -i inventory hardening_production.yml
```

Recomendado executar primeiro em `--check` (dry-run).

---

## Aviso Importante

Nunca aplique hardening de produção em VPS compartilhada.

Sempre valide acesso SSH antes de aplicar mudanças restritivas.

## 🤝 Contribua

Aceitamos contribuições! Veja como você pode ajudar:

1. Faça um fork do repositório
2. Crie sua branch de funcionalidade (`git checkout -b feature/AmazingFeature`)
3. Faça o commit das suas alterações (`git commit -m 'Adicionar uma AmazingFeature'`)
4. Envie para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

Para melhorias na documentação:

- Garanta explicações claras e concisas
- Inclua exemplos onde apropriado
- Siga a estrutura existente da documentação

## 📝 Licença

O Config Ubuntu é liberado sob a [Licença MIT](https://opensource.org/licenses/MIT).

## 📫 Contato

- Link do Projeto: [https://github.com/brunopirz/configubuntu](https://github.com/brunopirz/configubuntu)
- Rastreador de Issues: [GitHub Issues](https://github.com/brunopirz/configubuntu)

## 🙏 Agradecimentos

Inspirado no Ubinkaze (U-bin-ka-zeh) - "Ubuntu" + "Kaze" (🌀, vento em japonês) do @felipefontoura.

- [@rameerez](https://github.com/rameerez)
- [@felipefontoura](https://github.com/felipefontoura)
- [Omakub](https://omakub.org/)
- Contribuidores e mantenedores
- Comunidade de código aberto
