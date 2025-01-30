# Config Ubuntu Server 22.04+

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

Uma ferramenta de configuração pós-instalação para servidores Ubuntu, simplificando o processo de configuração e implementando as melhores práticas de segurança.

## 🚀 Funcionalidades

- Configuração automatizada pós-instalação
- Configurações de segurança aprimoradas
- Configuração de softwares comuns para servidor
- Otimizações de desempenho

## 📋 Requisitos

- Ubuntu Server (22.04)
- Acesso root ou sudo
- Conhecimentos básicos de linha de comando

## 💡 Uso

Execute o script de configuração no seu servidor:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/brunopirz/configubuntu/stable/boot.sh)
```

## 🐋 Docker Swarm

Se você precisar usar o Docker Swarm, execute:

```bash
docker swarm init --advertise-addr="<ip público>"
docker network create --driver=overlay network_public
```

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
