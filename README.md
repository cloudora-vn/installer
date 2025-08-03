# CoraPanel Installer

<div align="center">
  
![CoraPanel](https://img.shields.io/badge/CoraPanel-v2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)

**Professional Web Hosting Control Panel**

[Features](#features) • [Installation](#installation) • [Configuration](#configuration) • [Documentation](#documentation) • [Support](#support)

</div>

---

## 🚀 Features

### Core Features
- 🐳 **Docker Integration** - Full Docker and Docker Compose support
- 🗄️ **Database Management** - MySQL, MariaDB, PostgreSQL support
- 🔒 **SSL/TLS Support** - Let's Encrypt with auto-renewal
- 🔥 **Firewall Management** - Automatic firewall configuration
- 📊 **System Monitoring** - Real-time resource monitoring
- 🔄 **Auto Backup** - Scheduled backups with retention policies
- 🌐 **Multi-Architecture** - Support for AMD64, ARM64, ARMv7

### Supported Operating Systems
- Ubuntu 20.04/22.04/24.04 LTS
- Debian 10/11/12
- CentOS 7/8/Stream
- RHEL 8/9
- Rocky Linux 8/9
- AlmaLinux 8/9
- Fedora 37+

### System Requirements
- **CPU**: 1 core minimum (2+ cores recommended)
- **RAM**: 512MB minimum (1GB+ recommended)
- **Disk**: 2GB minimum (5GB+ recommended)
- **Network**: Internet connection required

---

## 📦 Installation

### Quick Install (Recommended)

Install the latest stable version:

```bash
curl -fsSL https://raw.githubusercontent.com/cloudora-vn/installer/main/quick_start.sh | bash
```

### Install with Custom Settings

```bash
# Download the installer
curl -fsSL -o quick_start.sh https://raw.githubusercontent.com/cloudora-vn/installer/main/quick_start.sh
chmod +x quick_start.sh

# Run with environment variables
PANEL_PORT=8080 \
PANEL_USERNAME=myadmin \
DATABASE_TYPE=mariadb \
./quick_start.sh
```

### Beta Version Installation

⚠️ **Warning**: Beta versions are for testing only, not for production use.

```bash
INSTALL_MODE=beta curl -fsSL https://raw.githubusercontent.com/cloudora-vn/installer/main/quick_start.sh | bash
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/cloudora-vn/installer.git
cd installer

# Run the installer
./install.sh latest  # or 'beta' for testing version
```

---

## ⚙️ Configuration Options

### Environment Variables

You can customize the installation using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PANEL_PORT` | 9999 | Web panel port |
| `PANEL_USERNAME` | admin | Admin username |
| `PANEL_PASSWORD` | *auto-generated* | Admin password |
| `PANEL_DOMAIN` | - | Domain for SSL setup |
| `INSTALL_DOCKER` | true | Install Docker |
| `INSTALL_DATABASE` | true | Install database server |
| `DATABASE_TYPE` | mysql | Database type (mysql/mariadb/postgresql) |
| `SSL_ENABLED` | false | Enable SSL/TLS |
| `FIREWALL_SETUP` | true | Configure firewall |

### Examples

#### Custom Port and Username
```bash
PANEL_PORT=8080 \
PANEL_USERNAME=administrator \
./install.sh
```

#### With SSL Certificate
```bash
PANEL_DOMAIN=panel.example.com \
SSL_ENABLED=true \
./install.sh
```

#### MariaDB Instead of MySQL
```bash
DATABASE_TYPE=mariadb \
./install.sh
```

#### Skip Docker Installation
```bash
INSTALL_DOCKER=false \
./install.sh
```

---

## 🔧 Post-Installation

### Access the Panel

After installation, you can access CoraPanel at:

- **HTTP**: `http://YOUR_SERVER_IP:9999`
- **HTTPS** (if SSL enabled): `https://YOUR_DOMAIN:9999`

Default credentials will be displayed after installation. Save them securely!

### Service Management

```bash
# Start CoraPanel
sudo systemctl start corapanel

# Stop CoraPanel
sudo systemctl stop corapanel

# Restart CoraPanel
sudo systemctl restart corapanel

# Check status
sudo systemctl status corapanel

# View logs
sudo journalctl -u corapanel -f

# Enable auto-start on boot
sudo systemctl enable corapanel
```

### Configuration Files

- **Main Config**: `/etc/corapanel/config.yaml`
- **Database Config**: `/etc/corapanel/database.conf`
- **Installation Info**: `/etc/corapanel/install.info`
- **Logs**: `/var/log/corapanel/`
- **Data**: `/var/lib/corapanel/`

---

## 🐳 Docker Management

If Docker was installed during setup:

### Docker Commands
```bash
# List containers
docker ps -a

# View Docker version
docker --version

# Docker Compose version
docker compose version
```

### Docker Compose Usage
```bash
# Using Docker Compose plugin (recommended)
docker compose up -d
docker compose down

# Using standalone Docker Compose
docker-compose up -d
docker-compose down
```

---

## 🔐 Security

### Firewall Ports

The installer automatically configures these ports:

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH | TCP |
| 80 | HTTP | TCP |
| 443 | HTTPS | TCP |
| 9999 | CoraPanel | TCP |

### SSL/TLS Certificates

If SSL is enabled, certificates are managed by Let's Encrypt:

```bash
# Certificate location
/etc/letsencrypt/live/YOUR_DOMAIN/

# Manual renewal
sudo certbot renew

# Check auto-renewal
sudo certbot renew --dry-run
```

### Database Security

- Root password is auto-generated and stored securely
- CoraPanel database user has limited privileges
- Credentials are saved in `/etc/corapanel/database.conf` (mode 600)

---

## 🔄 Updates

### Update to Latest Version
```bash
curl -fsSL https://raw.githubusercontent.com/cloudora-vn/installer/main/update.sh | bash
```

### Update to Specific Version
```bash
./install.sh v2.1.0
```

---

## 🗑️ Uninstallation

To completely remove CoraPanel:

```bash
curl -fsSL https://raw.githubusercontent.com/cloudora-vn/installer/main/uninstall.sh | bash
```

This will:
- Stop and disable CoraPanel service
- Remove all CoraPanel files
- Optionally remove Docker and database
- Clean up configuration files

---

## 🔍 Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Check what's using the port
sudo lsof -i :9999

# Change port during installation
PANEL_PORT=8080 ./install.sh
```

#### Service Won't Start
```bash
# Check service logs
sudo journalctl -u corapanel -n 50

# Check configuration
sudo cat /etc/corapanel/config.yaml

# Validate configuration syntax
corapanel --validate-config
```

#### Database Connection Failed
```bash
# Check database service
sudo systemctl status mysql  # or mariadb/postgresql

# Test connection
mysql -u corapanel -p

# Reset database password
sudo mysql -u root -p
```

#### SSL Certificate Issues
```bash
# Test certificate renewal
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Check certificate
sudo certbot certificates
```

### Debug Mode

Enable debug logging:

```bash
# Edit configuration
sudo nano /etc/corapanel/config.yaml

# Change log level
log:
  level: debug

# Restart service
sudo systemctl restart corapanel
```

---

## 📊 System Requirements Check

Run this command to check if your system meets requirements:

```bash
curl -fsSL https://raw.githubusercontent.com/cloudora-vn/installer/main/check_requirements.sh | bash
```

---

## 📁 Repository Structure

```
installer/
├── install.sh           # Main installer script
├── quick_start.sh       # Quick installation wrapper
├── update.sh           # Update script (coming soon)
├── uninstall.sh        # Uninstaller (coming soon)
├── check_requirements.sh # System checker (coming soon)
└── binaries/           # Binary files
    ├── beta/           # Beta version binaries
    │   ├── corapanel-agent.tar.gz
    │   ├── corapanel-core.tar.gz
    │   ├── version.txt
    │   └── build_time.txt
    └── latest/         # Stable version binaries
        ├── corapanel-agent.tar.gz
        ├── corapanel-core.tar.gz
        ├── version.txt
        └── build_time.txt
```

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Clone repository
git clone https://github.com/cloudora-vn/installer.git
cd installer

# Create feature branch
git checkout -b feature/your-feature

# Make changes and test
./test.sh

# Submit pull request
```

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🆘 Support

### Documentation
- Main Repository: [https://github.com/cloudora-vn/corapanel](https://github.com/cloudora-vn/corapanel)
- Issues: [https://github.com/cloudora-vn/installer/issues](https://github.com/cloudora-vn/installer/issues)

### Community
- [Discord Server](https://discord.gg/corapanel)
- [Community Forum](https://community.corapanel.com)

### Commercial Support
- Email: support@cloudora.vn
- Website: [https://cloudora.vn](https://cloudora.vn)

---

## 🎯 Roadmap

### Version 2.1 (Q1 2024)
- [ ] Kubernetes support
- [ ] Multi-server management
- [ ] Advanced monitoring dashboard
- [ ] API v2

### Version 2.2 (Q2 2024)
- [ ] Email server integration
- [ ] DNS management
- [ ] Backup to S3/Cloud storage
- [ ] Mobile app

---

## 📈 Build Information

- Latest build: 2025-08-03 08:41:16 UTC
- Latest commit: 57ab7a11453cb2bbf34bbd9e9034b2a9d6bea0be

---

<div align="center">
  
**Made with ❤️ by [Cloudora VN](https://cloudora.vn)**

© 2024 Cloudora VN. All rights reserved.

</div>