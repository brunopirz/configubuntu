# Config Ubuntu Server 22.04+

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

Inspirado no Ubinkaze (U-bin-ka-zeh) - "Ubuntu" + "Kaze" (🌀, wind in Japanese) do @felipefontoura.

An comprehensive post-installation configuration tool for Ubuntu servers, streamlining the setup process and implementing best practices.

## 🚀 Features

- Automated post-installation configuration
- Security hardening settings
- Common server software setup
- Performance optimizations

## 📋 Prerequisites

- Ubuntu Server (20.04)
- Root or sudo access
- Basic command line knowledge

## 💡 Usage

Run the setup script on your server:

```bash
bash <(curl -sSL https://raw.githubusercontent.com/brunopirz/configubuntu/stable/boot.sh)
```

## 🐋 Docker Swarm

If you need to use Docker Swarm run:

```bash
docker swarm init --advertise-addr="<public ip>"
docker network create --driver=overlay network_public
```

## 🤝 Contributing

We welcome contributions to Ubinkaze! Here's how you can help:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

For documentation improvements:

- Ensure clear and concise explanations
- Include examples where appropriate
- Follow the existing documentation structure

## 📝 License

Ubinkaze is released under the [MIT License](https://opensource.org/licenses/MIT).

## 📫 Contact

- Project Link: [https://github.com/brunopirz/configubuntu](https://github.com/brunopirz/configubuntu)
- Issue Tracker: [GitHub Issues](https://github.com/brunopirz/configubuntu)

## 🙏 Acknowledgments

- [@rameerez](https://github.com/rameerez)
- [@felipefontoura](https://github.com/felipefontoura) 
- [Omakub](https://omakub.org/)
- Contributors and maintainers
- Open source community
