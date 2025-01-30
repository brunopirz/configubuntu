#!/bin/bash

set -euo pipefail

banner='▗   █████████                         ██████   ███                 
  ███░░░░░███                       ███░░███ ░░░                  
 ███     ░░░   ██████  ████████    ░███ ░░░  ████   ███████       
░███          ███░░███░░███░░███  ███████   ░░███  ███░░███       
░███         ░███ ░███ ░███ ░███ ░░░███░     ░███ ░███ ░███       
░░███     ███░███ ░███ ░███ ░███   ░███      ░███ ░███ ░███       
 ░░█████████ ░░██████  ████ █████  █████     █████░░███████       
  ░░░░░░░░░   ░░░░░░  ░░░░ ░░░░░  ░░░░░     ░░░░░  ░░░░░███       
                                                   ███ ░███       
                                                  ░░██████        
                                                   ░░░░░░         
 █████  █████ █████                            █████              
░░███  ░░███ ░░███                            ░░███               
 ░███   ░███  ░███████  █████ ████ ████████   ███████   █████ ████
 ░███   ░███  ░███░░███░░███ ░███ ░░███░░███ ░░░███░   ░░███ ░███ 
 ░███   ░███  ░███ ░███ ░███ ░███  ░███ ░███   ░███     ░███ ░███ 
 ░███   ░███  ░███ ░███ ░███ ░███  ░███ ░███   ░███ ███ ░███ ░███ 
 ░░████████   ████████  ░░████████ ████ █████  ░░█████  ░░████████
  ░░░░░░░░   ░░░░░░░░    ░░░░░░░░ ░░░░ ░░░░░    ░░░░░    ░░░░░░░░
  '

echo -e "$banner"
echo "=> Configure rapidamente seu Ubuntu Server 22.04 ou superior"
echo -e "\nBegin installation (or abort with ctrl+c)..."

sudo apt-get update >/dev/null
sudo apt-get install -y git >/dev/null

echo "clonando direrório..."
rm -rf ~/.local/share/configubuntu
git clone https://github.com/brunopirz/configubuntu.git ~/.local/share/configubuntu >/dev/null

CONFIGUBUNTU_REF=${CONFIGUBUNTU_REF:-"stable"}

if [[ $CONFIGUBUNTU_REF != "main" ]]; then
  cd ~/.local/share/configubuntu
  git fetch origin "$CONFIGUBUNTU_REF" && git checkout "$CONFIGUBUNTU_REF"
  cd - >/dev/null
fi

echo "Inicializando a instalação do Config Ubuntu..."
source ~/.local/share/configubuntu/install.sh
