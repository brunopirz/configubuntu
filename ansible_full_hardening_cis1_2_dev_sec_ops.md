# Ansible Full Hardening – CIS Level 1 + Level 2

Este documento descreve a arquitetura completa de hardening para Ubuntu 22.04+ seguindo CIS Benchmark, práticas DevSecOps e princípios de infraestrutura imutável.

---

## Objetivo

Criar uma base única de segurança que possa ser aplicada de forma controlada em diferentes ambientes:

* VPS compartilhada (desenvolvimento)
* Servidor dedicado / cloud (produção)

---

## Pilares de Segurança

### 1. CIS Benchmark

* Level 1: Segurança padrão, compatível com ambientes compartilhados
* Level 2: Segurança restritiva, apenas para ambientes dedicados

### 2. Hardening por camadas

* Sistema operacional
* Kernel
* Rede
* Usuários
* Docker
* Auditoria

### 3. Automação

* Ansible como engine principal
* Estrutura preparada para roles
* Compatível com Terraform (futuro)

---

## Componentes Incluídos

### Sistema

* Atualizações automáticas
* Timezone e locale
* Permissões padrão seguras

### Usuários e autenticação

* Política de senha forte
* Bloqueio de usuários inativos
* Remoção de usuários de sistema desnecessários

### SSH

* Protocol 2
* Root login desativado
* Ciphers seguros
* Idle timeout

### Firewall

* UFW como padrão
* Política deny by default
* Liberação explícita de portas

### Kernel (condicional)

* sysctl hardening
* ASLR
* Proteções de rede

### Docker

* Logs habilitados
* User namespaces
* Limite de capabilities

### Auditoria

* Lynis
* Journald persistente
* Logrotate

---

## Estratégia por Ambiente

| Ambiente | CIS   | Kernel | Docker   | Auditoria |
| -------- | ----- | ------ | -------- | --------- |
| Shared   | L1    | Leve   | Básico   | Passiva   |
| Prod     | L1+L2 | Forte  | Avançado | Ativa     |

---

## Resultado Final

* Segurança progressiva
* Zero lock-in
* Preparado para compliance
* Evolução sem retrabalho
