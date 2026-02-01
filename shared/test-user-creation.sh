#!/bin/bash

# Script de teste para validar correção do usuário docker

echo "========================================="
echo "Teste de Criação do Usuário Docker"
echo "========================================="
echo ""

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função de teste
test_user_creation() {
  echo -e "${YELLOW}Testando criação do usuário docker...${NC}"
  
  # Verificar se usuário docker já existe
  if id docker &>/dev/null 2>&1; then
    echo -e "${YELLOW}Usuário docker já existe, removendo para testar...${NC}"
    userdel -r docker 2>/dev/null || true
    sleep 1
  fi
  
  # Criar usuário docker (método corrigido)
  echo "1. Criando usuário docker..."
  if useradd -m -s /bin/bash docker; then
    echo -e "${GREEN}✓ Usuário criado${NC}"
  else
    echo -e "${RED}✗ Falha ao criar usuário${NC}"
    return 1
  fi
  
  # Adicionar aos grupos
  echo "2. Adicionando aos grupos docker e sudo..."
  if usermod -aG docker,sudo docker; then
    echo -e "${GREEN}✓ Grupos adicionados${NC}"
  else
    echo -e "${RED}✗ Falha ao adicionar aos grupos${NC}"
    return 1
  fi
  
  # Verificar grupos
  echo "3. Verificando grupos..."
  GROUPS=$(groups docker 2>/dev/null | cut -d: -f2)
  echo "   Grupos do usuário docker:$GROUPS"
  
  if [[ "$GROUPS" == *"docker"* ]] && [[ "$GROUPS" == *"sudo"* ]]; then
    echo -e "${GREEN}✓ Grupos corretos${NC}"
  else
    echo -e "${RED}✗ Grupos incorretos${NC}"
    return 1
  fi
  
  # Verificar home directory
  echo "4. Verificando home directory..."
  if [ -d /home/docker ]; then
    echo -e "${GREEN}✓ Home directory existe: /home/docker${NC}"
  else
    echo -e "${RED}✗ Home directory não existe${NC}"
    return 1
  fi
  
  # Verificar shell
  echo "5. Verificando shell..."
  SHELL=$(getent passwd docker | cut -d: -f7)
  if [ "$SHELL" = "/bin/bash" ]; then
    echo -e "${GREEN}✓ Shell correto: /bin/bash${NC}"
  else
    echo -e "${RED}✗ Shell incorreto: $SHELL${NC}"
    return 1
  fi
  
  echo ""
  echo -e "${GREEN}=========================================${NC}"
  echo -e "${GREEN}TESTE PASSOU! Usuário docker criado corretamente${NC}"
  echo -e "${GREEN}=========================================${NC}"
  
  return 0
}

# Executar teste
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script precisa ser executado como root${NC}" 
   exit 1
fi

test_user_creation

echo ""
echo "Informações do usuário docker:"
echo "-----------------------------------"
id docker
echo ""
echo "Grupos:"
groups docker
echo ""
echo "Home:"
ls -la /home/docker 2>/dev/null | head -5
