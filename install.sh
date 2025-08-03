#!/bin/bash
set -e

# CoraPanel Professional Installer
# Version: 2.0.0
# Usage: ./install.sh [version]
# version can be: latest (default), beta, or a specific version like v1.0.0

VERSION=${1:-latest}
BASE_URL="https://raw.githubusercontent.com/cloudora-vn/installer/main/binaries"
INSTALL_DIR="/opt/corapanel"
DATA_DIR="/var/lib/corapanel"
CONFIG_DIR="/etc/corapanel"
LOG_DIR="/var/log/corapanel"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration variables
PANEL_PORT=${PANEL_PORT:-9999}
PANEL_USERNAME=${PANEL_USERNAME:-admin}
PANEL_PASSWORD=${PANEL_PASSWORD:-}
PANEL_DOMAIN=${PANEL_DOMAIN:-}
INSTALL_DOCKER=${INSTALL_DOCKER:-true}
INSTALL_DATABASE=${INSTALL_DATABASE:-true}
DATABASE_TYPE=${DATABASE_TYPE:-mysql}  # mysql, mariadb, or postgresql
SSL_ENABLED=${SSL_ENABLED:-false}
FIREWALL_SETUP=${FIREWALL_SETUP:-true}

# System info
OS=""
OS_VERSION=""
ARCH=""
SUDO=""

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║                                                    ║"
    echo "║           CoraPanel Professional Setup             ║"
    echo "║                  Version 2.0.0                     ║"
    echo "║             Powered by Cloudora VN                 ║"
    echo "║                                                    ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Progress indicator
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Log function
log() {
    echo -e "${2:-$GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Error handler
error_exit() {
    echo -e "${RED}✗ Error: $1${NC}" >&2
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    else
        SUDO="sudo"
        log "This script requires sudo privileges" "$YELLOW"
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # Save VERSION variable before sourcing os-release
        local SAVED_VERSION="$VERSION"
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        # Restore VERSION variable
        VERSION="$SAVED_VERSION"
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
    else
        error_exit "Cannot detect OS"
    fi
    
    log "Detected OS: $OS $OS_VERSION"
    
    # Check supported OS
    case $OS in
        ubuntu|debian|centos|rhel|fedora|rocky|almalinux|opensuse*)
            ;;
        *)
            error_exit "Unsupported OS: $OS"
            ;;
    esac
}

# Detect architecture
detect_architecture() {
    ARCH=$(uname -m)
    case ${ARCH} in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l|armv7)
            ARCH="armv7"
            ;;
        *)
            error_exit "Unsupported architecture: ${ARCH}"
            ;;
    esac
    
    log "Detected Architecture: ${ARCH}"
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..." "$YELLOW"
    
    # Check minimum RAM (1GB recommended)
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 512 ]]; then
        error_exit "Insufficient RAM. Minimum 512MB required (1GB recommended)"
    elif [[ $total_ram -lt 1024 ]]; then
        log "Warning: Low RAM detected. 1GB+ recommended for optimal performance" "$YELLOW"
    fi
    
    # Check available disk space (5GB recommended)
    local available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_space -lt 2 ]]; then
        error_exit "Insufficient disk space. Minimum 2GB required"
    elif [[ $available_space -lt 5 ]]; then
        log "Warning: Low disk space. 5GB+ recommended" "$YELLOW"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 1 ]]; then
        error_exit "Cannot detect CPU cores"
    fi
    log "CPU Cores: $cpu_cores"
    
    # Check network connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log "Warning: No internet connection detected" "$YELLOW"
    fi
    
    log "System requirements check passed" "$GREEN"
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..." "$YELLOW"
    
    case $OS in
        ubuntu|debian)
            ${SUDO} apt-get update
            ${SUDO} apt-get install -y \
                curl \
                wget \
                tar \
                gzip \
                ca-certificates \
                gnupg \
                lsb-release \
                software-properties-common \
                apt-transport-https \
                iptables \
                net-tools \
                htop \
                git \
                vim \
                ufw
            ;;
        centos|rhel|fedora|rocky|almalinux)
            ${SUDO} yum install -y epel-release
            ${SUDO} yum install -y \
                curl \
                wget \
                tar \
                gzip \
                ca-certificates \
                gnupg \
                yum-utils \
                iptables \
                net-tools \
                htop \
                git \
                vim \
                firewalld
            ;;
        *)
            log "Please install dependencies manually for $OS" "$YELLOW"
            ;;
    esac
    
    log "Dependencies installed successfully" "$GREEN"
}

# Install Docker
install_docker() {
    if [[ "$INSTALL_DOCKER" != "true" ]]; then
        log "Skipping Docker installation"
        return
    fi
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log "Docker is already installed"
        docker --version
        return
    fi
    
    log "Installing Docker..." "$YELLOW"
    
    case $OS in
        ubuntu|debian)
            # Remove old versions
            ${SUDO} apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            
            # Add Docker's official GPG key
            ${SUDO} mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            
            # Set up repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
                $(lsb_release -cs) stable" | ${SUDO} tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            ${SUDO} apt-get update
            ${SUDO} apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        centos|rhel|fedora|rocky|almalinux)
            # Remove old versions
            ${SUDO} yum remove -y docker \
                docker-client \
                docker-client-latest \
                docker-common \
                docker-latest \
                docker-latest-logrotate \
                docker-logrotate \
                docker-engine 2>/dev/null || true
            
            # Set up repository
            ${SUDO} yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            
            # Install Docker
            ${SUDO} yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            ;;
            
        *)
            log "Please install Docker manually for $OS" "$YELLOW"
            return
            ;;
    esac
    
    # Start and enable Docker
    ${SUDO} systemctl start docker
    ${SUDO} systemctl enable docker
    
    # Add current user to docker group
    if [[ $EUID -ne 0 ]]; then
        ${SUDO} usermod -aG docker $USER
        log "Added $USER to docker group. Please log out and back in for this to take effect." "$YELLOW"
    fi
    
    # Install Docker Compose standalone (as backup)
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose standalone..." "$YELLOW"
        ${SUDO} curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        ${SUDO} chmod +x /usr/local/bin/docker-compose
    fi
    
    log "Docker installed successfully" "$GREEN"
    docker --version
    docker compose version || docker-compose --version
}

# Setup Database
setup_database() {
    if [[ "$INSTALL_DATABASE" != "true" ]]; then
        log "Skipping database setup"
        return
    fi
    
    log "Setting up database ($DATABASE_TYPE)..." "$YELLOW"
    
    # Generate random password if not provided
    DB_ROOT_PASSWORD=$(openssl rand -base64 32)
    DB_CORAPANEL_PASSWORD=$(openssl rand -base64 32)
    
    case $DATABASE_TYPE in
        mysql|mariadb)
            if [[ "$DATABASE_TYPE" == "mariadb" ]]; then
                # Install MariaDB
                case $OS in
                    ubuntu|debian)
                        ${SUDO} apt-get install -y mariadb-server mariadb-client
                        ;;
                    centos|rhel|fedora|rocky|almalinux)
                        ${SUDO} yum install -y mariadb-server mariadb
                        ;;
                esac
            else
                # Install MySQL
                case $OS in
                    ubuntu|debian)
                        ${SUDO} apt-get install -y mysql-server mysql-client
                        ;;
                    centos|rhel|fedora|rocky|almalinux)
                        ${SUDO} yum install -y mysql-server mysql
                        ;;
                esac
            fi
            
            # Start service
            ${SUDO} systemctl start ${DATABASE_TYPE}
            ${SUDO} systemctl enable ${DATABASE_TYPE}
            
            # Secure installation
            ${SUDO} mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "DELETE FROM mysql.user WHERE User='';"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "DROP DATABASE IF EXISTS test;"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
            
            # Create CoraPanel database and user
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS corapanel;"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS 'corapanel'@'localhost' IDENTIFIED BY '${DB_CORAPANEL_PASSWORD}';"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON corapanel.* TO 'corapanel'@'localhost';"
            ${SUDO} mysql -u root -p${DB_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"
            ;;
            
        postgresql)
            # Install PostgreSQL
            case $OS in
                ubuntu|debian)
                    ${SUDO} apt-get install -y postgresql postgresql-contrib
                    ;;
                centos|rhel|fedora|rocky|almalinux)
                    ${SUDO} yum install -y postgresql-server postgresql-contrib
                    ${SUDO} postgresql-setup initdb
                    ;;
            esac
            
            # Start service
            ${SUDO} systemctl start postgresql
            ${SUDO} systemctl enable postgresql
            
            # Create database and user
            ${SUDO} -u postgres psql -c "CREATE DATABASE corapanel;"
            ${SUDO} -u postgres psql -c "CREATE USER corapanel WITH ENCRYPTED PASSWORD '${DB_CORAPANEL_PASSWORD}';"
            ${SUDO} -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE corapanel TO corapanel;"
            ;;
    esac
    
    # Save database credentials
    cat > ${CONFIG_DIR}/database.conf <<EOF
DATABASE_TYPE=${DATABASE_TYPE}
DATABASE_HOST=localhost
DATABASE_PORT=3306
DATABASE_NAME=corapanel
DATABASE_USER=corapanel
DATABASE_PASSWORD=${DB_CORAPANEL_PASSWORD}
DATABASE_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
EOF
    
    ${SUDO} chmod 600 ${CONFIG_DIR}/database.conf
    
    log "Database setup completed" "$GREEN"
}

# Configure Firewall
configure_firewall() {
    if [[ "$FIREWALL_SETUP" != "true" ]]; then
        log "Skipping firewall configuration"
        return
    fi
    
    log "Configuring firewall..." "$YELLOW"
    
    case $OS in
        ubuntu|debian)
            # Use UFW
            ${SUDO} ufw --force enable
            ${SUDO} ufw allow 22/tcp      # SSH
            ${SUDO} ufw allow 80/tcp      # HTTP
            ${SUDO} ufw allow 443/tcp     # HTTPS
            ${SUDO} ufw allow ${PANEL_PORT}/tcp  # Panel
            ${SUDO} ufw reload
            log "UFW firewall configured" "$GREEN"
            ;;
            
        centos|rhel|fedora|rocky|almalinux)
            # Use Firewalld
            ${SUDO} systemctl start firewalld
            ${SUDO} systemctl enable firewalld
            ${SUDO} firewall-cmd --permanent --add-service=ssh
            ${SUDO} firewall-cmd --permanent --add-service=http
            ${SUDO} firewall-cmd --permanent --add-service=https
            ${SUDO} firewall-cmd --permanent --add-port=${PANEL_PORT}/tcp
            ${SUDO} firewall-cmd --reload
            log "Firewalld configured" "$GREEN"
            ;;
            
        *)
            log "Please configure firewall manually for $OS" "$YELLOW"
            ;;
    esac
}

# Download with retry logic
download_with_retry() {
    local url=$1
    local output=$2
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        log "Downloading from: $url (attempt $((retry+1))/$max_retries)" "$YELLOW"
        if ${SUDO} curl -L -f -o "$output" "$url"; then
            log "Download successful: $output" "$GREEN"
            return 0
        fi
        retry=$((retry+1))
        if [ $retry -lt $max_retries ]; then
            log "Download failed, retrying in 2 seconds..." "$YELLOW"
            sleep 2
        fi
    done
    
    log "Failed to download after $max_retries attempts: $url" "$RED"
    return 1
}

# Install CoraPanel
install_corapanel() {
    log "Installing CoraPanel..." "$YELLOW"
    
    # Determine install mode
    if [[ "$VERSION" == "beta" ]]; then
        INSTALL_MODE="beta"
        log "Installing BETA version (not for production)" "$YELLOW"
    elif [[ "$VERSION" == "latest" ]]; then
        INSTALL_MODE="latest"
        log "Installing latest stable version"
    else
        INSTALL_MODE="releases"
        log "Installing version ${VERSION}"
    fi
    
    # Create directories
    ${SUDO} mkdir -p ${INSTALL_DIR}
    ${SUDO} mkdir -p ${DATA_DIR}
    ${SUDO} mkdir -p ${CONFIG_DIR}
    ${SUDO} mkdir -p ${LOG_DIR}
    
    cd ${INSTALL_DIR}
    
    # Get actual version for beta/latest
    if [[ "$INSTALL_MODE" == "beta" ]] || [[ "$INSTALL_MODE" == "latest" ]]; then
        VERSION_URL="${BASE_URL}/${INSTALL_MODE}/version.txt"
        ACTUAL_VERSION=$(curl -sL "$VERSION_URL" 2>/dev/null | head -n1 | tr -d '\r\n')
        
        if [[ -n "$ACTUAL_VERSION" ]]; then
            log "Version: ${ACTUAL_VERSION}"
        fi
        
        DOWNLOAD_PATH="${BASE_URL}/${INSTALL_MODE}"
    else
        ACTUAL_VERSION="${VERSION}"
        DOWNLOAD_PATH="${BASE_URL}/releases/${VERSION}"
    fi
    
    # Download binaries
    log "Downloading CoraPanel binaries..."
    
    if [[ "$INSTALL_MODE" == "beta" ]] || [[ "$INSTALL_MODE" == "latest" ]]; then
        # Beta files don't have architecture in filename
        download_with_retry "${DOWNLOAD_PATH}/corapanel-agent.tar.gz" "agent.tar.gz" || error_exit "Failed to download agent"
        download_with_retry "${DOWNLOAD_PATH}/corapanel-core.tar.gz" "core.tar.gz" || error_exit "Failed to download core"
    else
        download_with_retry "${DOWNLOAD_PATH}/corapanel-agent-${ARCH}.tar.gz" "agent.tar.gz" || error_exit "Failed to download agent"
        download_with_retry "${DOWNLOAD_PATH}/corapanel-core-${ARCH}.tar.gz" "core.tar.gz" || error_exit "Failed to download core"
    fi
    
    # Extract files
    log "Extracting files..."
    ${SUDO} tar -xzf agent.tar.gz || error_exit "Failed to extract agent"
    ${SUDO} tar -xzf core.tar.gz || error_exit "Failed to extract core"
    
    # Set permissions
    ${SUDO} chmod +x corapanel-agent
    ${SUDO} chmod +x corapanel-core
    
    # Create symlinks
    ${SUDO} ln -sf ${INSTALL_DIR}/corapanel-agent /usr/local/bin/corapanel-agent
    ${SUDO} ln -sf ${INSTALL_DIR}/corapanel-core /usr/local/bin/corapanel-core
    ${SUDO} ln -sf ${INSTALL_DIR}/corapanel-core /usr/local/bin/corapanel
    
    # Cleanup
    ${SUDO} rm -f agent.tar.gz core.tar.gz
    
    log "CoraPanel binaries installed" "$GREEN"
}

# Create configuration
create_configuration() {
    log "Creating configuration..." "$YELLOW"
    
    # Generate random password if not set
    if [[ -z "$PANEL_PASSWORD" ]]; then
        PANEL_PASSWORD=$(openssl rand -base64 12)
    fi
    
    # Create main config
    cat > ${CONFIG_DIR}/config.yaml <<EOF
server:
  port: ${PANEL_PORT}
  host: 0.0.0.0
  domain: ${PANEL_DOMAIN:-localhost}

auth:
  username: ${PANEL_USERNAME}
  password: ${PANEL_PASSWORD}

database:
  type: ${DATABASE_TYPE}
  host: localhost
  port: 3306
  name: corapanel
  user: corapanel

docker:
  enabled: ${INSTALL_DOCKER}
  socket: /var/run/docker.sock

ssl:
  enabled: ${SSL_ENABLED}
  auto_renew: true

paths:
  data: ${DATA_DIR}
  logs: ${LOG_DIR}
  config: ${CONFIG_DIR}

log:
  level: info
  file: ${LOG_DIR}/corapanel.log
  max_size: 100M
  max_backups: 10

monitoring:
  enabled: true
  interval: 60

backup:
  enabled: true
  path: ${DATA_DIR}/backups
  schedule: "0 2 * * *"
  retention_days: 30
EOF
    
    ${SUDO} chmod 600 ${CONFIG_DIR}/config.yaml
    
    log "Configuration created" "$GREEN"
}

# Create systemd service
create_service() {
    log "Creating systemd service..." "$YELLOW"
    
    cat > /tmp/corapanel.service <<EOF
[Unit]
Description=CoraPanel Control Panel
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStartPre=/bin/sleep 10
ExecStart=/usr/local/bin/corapanel-core
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/corapanel.log
StandardError=append:${LOG_DIR}/corapanel.error.log

[Install]
WantedBy=multi-user.target
EOF
    
    ${SUDO} mv /tmp/corapanel.service /etc/systemd/system/corapanel.service
    ${SUDO} systemctl daemon-reload
    ${SUDO} systemctl enable corapanel
    
    log "Systemd service created" "$GREEN"
}

# Setup SSL (optional)
setup_ssl() {
    if [[ "$SSL_ENABLED" != "true" ]] || [[ -z "$PANEL_DOMAIN" ]]; then
        return
    fi
    
    log "Setting up SSL certificate..." "$YELLOW"
    
    # Install certbot
    case $OS in
        ubuntu|debian)
            ${SUDO} apt-get install -y certbot
            ;;
        centos|rhel|fedora|rocky|almalinux)
            ${SUDO} yum install -y certbot
            ;;
    esac
    
    # Get certificate
    ${SUDO} certbot certonly --standalone -d ${PANEL_DOMAIN} --non-interactive --agree-tos --email admin@${PANEL_DOMAIN}
    
    # Update config with SSL paths
    cat >> ${CONFIG_DIR}/config.yaml <<EOF

ssl:
  enabled: true
  cert: /etc/letsencrypt/live/${PANEL_DOMAIN}/fullchain.pem
  key: /etc/letsencrypt/live/${PANEL_DOMAIN}/privkey.pem
EOF
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    log "SSL certificate configured" "$GREEN"
}

# Post installation
post_installation() {
    log "Running post-installation tasks..." "$YELLOW"
    
    # Create initial admin user in database
    if [[ "$INSTALL_DATABASE" == "true" ]]; then
        # This would normally be done by the application itself
        log "Database configured for first run"
    fi
    
    # Start service
    ${SUDO} systemctl start corapanel
    
    # Wait for service to start
    sleep 5
    
    # Check if service is running
    if systemctl is-active --quiet corapanel; then
        log "CoraPanel service is running" "$GREEN"
    else
        log "CoraPanel service failed to start. Check logs: journalctl -u corapanel" "$RED"
    fi
    
    # Save installation info
    cat > ${CONFIG_DIR}/install.info <<EOF
Installation Date: $(date)
Version: ${ACTUAL_VERSION:-$VERSION}
Mode: ${INSTALL_MODE}
Architecture: ${ARCH}
OS: ${OS} ${OS_VERSION}
Panel Port: ${PANEL_PORT}
Panel Username: ${PANEL_USERNAME}
Panel Password: ${PANEL_PASSWORD}
Docker Installed: ${INSTALL_DOCKER}
Database Type: ${DATABASE_TYPE}
SSL Enabled: ${SSL_ENABLED}
Domain: ${PANEL_DOMAIN:-Not configured}
EOF
    
    ${SUDO} chmod 600 ${CONFIG_DIR}/install.info
}

# Display summary
display_summary() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          Installation Completed Successfully!       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}CoraPanel Details:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${YELLOW}Version:${NC} ${ACTUAL_VERSION:-$VERSION}"
    if [[ "$INSTALL_MODE" == "beta" ]]; then
        echo -e "${YELLOW}Mode:${NC} ${RED}BETA (Testing Only)${NC}"
    fi
    echo -e "${YELLOW}Installation Path:${NC} ${INSTALL_DIR}"
    echo -e "${YELLOW}Configuration:${NC} ${CONFIG_DIR}/config.yaml"
    echo -e "${YELLOW}Logs:${NC} ${LOG_DIR}/"
    echo ""
    echo -e "${GREEN}Access Information:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get IP addresses
    local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
    if [[ -n "$ips" ]]; then
        echo -e "${YELLOW}Access URLs:${NC}"
        if [[ "$SSL_ENABLED" == "true" ]] && [[ -n "$PANEL_DOMAIN" ]]; then
            echo -e "  ${GREEN}➜${NC} https://${PANEL_DOMAIN}:${PANEL_PORT}"
        else
            echo "$ips" | while read ip; do
                echo -e "  ${GREEN}➜${NC} http://$ip:${PANEL_PORT}"
            done
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Login Credentials:${NC}"
    echo -e "  Username: ${GREEN}${PANEL_USERNAME}${NC}"
    echo -e "  Password: ${GREEN}${PANEL_PASSWORD}${NC}"
    echo ""
    
    if [[ "$INSTALL_DATABASE" == "true" ]]; then
        echo -e "${GREEN}Database Information:${NC}"
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "  Type: ${DATABASE_TYPE}"
        echo -e "  Credentials saved in: ${CONFIG_DIR}/database.conf"
        echo ""
    fi
    
    if [[ "$INSTALL_DOCKER" == "true" ]]; then
        echo -e "${GREEN}Docker Status:${NC}"
        echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        docker --version
        echo ""
    fi
    
    echo -e "${GREEN}Service Management:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Start:   sudo systemctl start corapanel"
    echo "  Stop:    sudo systemctl stop corapanel"
    echo "  Restart: sudo systemctl restart corapanel"
    echo "  Status:  sudo systemctl status corapanel"
    echo "  Logs:    sudo journalctl -u corapanel -f"
    echo ""
    
    echo -e "${CYAN}Documentation:${NC} https://github.com/cloudora-vn/installer"
    echo -e "${CYAN}Support:${NC} support@cloudora.vn"
    echo ""
    echo -e "${GREEN}✓${NC} Thank you for choosing CoraPanel!"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main installation flow
main() {
    show_banner
    
    # Pre-installation checks
    check_root
    detect_os
    detect_architecture
    check_requirements
    
    # Installation steps
    install_dependencies
    install_docker
    setup_database
    configure_firewall
    
    # Install CoraPanel
    install_corapanel
    create_configuration
    create_service
    setup_ssl
    
    # Post installation
    post_installation
    
    # Display summary
    display_summary
}

# Run main function with error handling
trap 'error_exit "Installation failed at line $LINENO"' ERR
main "$@"