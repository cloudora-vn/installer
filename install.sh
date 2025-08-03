#!/bin/bash
set -e

# CoraPanel Quick Installer
# Usage: ./install.sh [version]
# version can be: latest (default), beta, or a specific version like v1.0.0
VERSION=${1:-latest}
BASE_URL="https://raw.githubusercontent.com/cloudora-vn/installer/main/binaries"
INSTALL_DIR="/opt/corapanel"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Determine install mode
if [[ "$VERSION" == "beta" ]]; then
    INSTALL_MODE="beta"
    echo -e "${YELLOW}Installing CoraPanel BETA version...${NC}"
elif [[ "$VERSION" == "latest" ]]; then
    INSTALL_MODE="latest"
    echo -e "${GREEN}Installing CoraPanel LATEST stable version...${NC}"
else
    # Specific version requested
    INSTALL_MODE="releases"
    echo -e "${GREEN}Installing CoraPanel version ${VERSION}...${NC}"
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   SUDO=""
else
   SUDO="sudo"
   echo -e "${YELLOW}This script requires sudo privileges${NC}"
fi

# Detect OS
OS="unknown"
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
fi

# Detect architecture
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="armv7"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
        exit 1
        ;;
esac

echo "Detected OS: ${OS}"
echo "Detected Architecture: ${ARCH}"

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
DEPS=("curl" "tar")
for dep in "${DEPS[@]}"; do
    if ! command -v $dep &> /dev/null; then
        echo -e "${RED}$dep is not installed. Installing...${NC}"
        case ${OS} in
            ubuntu|debian)
                ${SUDO} apt-get update && ${SUDO} apt-get install -y $dep
                ;;
            centos|rhel|fedora)
                ${SUDO} yum install -y $dep
                ;;
            *)
                echo -e "${RED}Please install $dep manually${NC}"
                exit 1
                ;;
        esac
    fi
done

# Create installation directory
${SUDO} mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

# Download binaries with retry logic
download_with_retry() {
    local url=$1
    local output=$2
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        echo -e "${YELLOW}Downloading $output (attempt $((retry+1))/$max_retries)...${NC}"
        if ${SUDO} curl -L -f -o "$output" "$url" 2>/dev/null; then
            echo -e "${GREEN}Download successful${NC}"
            return 0
        fi
        retry=$((retry+1))
        [ $retry -lt $max_retries ] && sleep 2
    done
    
    echo -e "${RED}Failed to download $output after $max_retries attempts${NC}"
    return 1
}

# Get actual version for beta/latest
if [[ "$INSTALL_MODE" == "beta" ]] || [[ "$INSTALL_MODE" == "latest" ]]; then
    # Try to get version from version.txt file
    VERSION_URL="${BASE_URL}/${INSTALL_MODE}/version.txt"
    ACTUAL_VERSION=$(curl -sL "$VERSION_URL" 2>/dev/null | head -n1 | tr -d '\r\n')
    
    if [[ -n "$ACTUAL_VERSION" ]]; then
        echo -e "${GREEN}Version detected: ${ACTUAL_VERSION}${NC}"
    else
        echo -e "${YELLOW}Could not detect version, using ${INSTALL_MODE} folder${NC}"
        ACTUAL_VERSION="${INSTALL_MODE}"
    fi
    
    # For beta and latest, files are directly in the folder
    DOWNLOAD_PATH="${BASE_URL}/${INSTALL_MODE}"
else
    # For specific versions, use releases folder structure
    ACTUAL_VERSION="${VERSION}"
    DOWNLOAD_PATH="${BASE_URL}/releases/${VERSION}"
fi

echo "Downloading CoraPanel Agent..."
if [[ "$INSTALL_MODE" == "beta" ]] || [[ "$INSTALL_MODE" == "latest" ]]; then
    # Beta and latest don't have architecture in filename
    download_with_retry "${DOWNLOAD_PATH}/corapanel-agent.tar.gz" "agent.tar.gz" || exit 1
else
    # Release versions have architecture in filename
    download_with_retry "${DOWNLOAD_PATH}/corapanel-agent-${ARCH}.tar.gz" "agent.tar.gz" || exit 1
fi

echo "Downloading CoraPanel Core..."
if [[ "$INSTALL_MODE" == "beta" ]] || [[ "$INSTALL_MODE" == "latest" ]]; then
    # Beta and latest don't have architecture in filename
    download_with_retry "${DOWNLOAD_PATH}/corapanel-core.tar.gz" "core.tar.gz" || exit 1
else
    # Release versions have architecture in filename  
    download_with_retry "${DOWNLOAD_PATH}/corapanel-core-${ARCH}.tar.gz" "core.tar.gz" || exit 1
fi

# Extract with error handling
echo -e "${YELLOW}Extracting files...${NC}"
${SUDO} tar -xzf agent.tar.gz || { echo -e "${RED}Failed to extract agent.tar.gz${NC}"; exit 1; }
${SUDO} tar -xzf core.tar.gz || { echo -e "${RED}Failed to extract core.tar.gz${NC}"; exit 1; }

# Set permissions
${SUDO} chmod +x corapanel-agent
${SUDO} chmod +x corapanel-core

# Create symlinks
echo -e "${YELLOW}Creating symlinks...${NC}"
${SUDO} ln -sf ${INSTALL_DIR}/corapanel-agent /usr/local/bin/corapanel-agent
${SUDO} ln -sf ${INSTALL_DIR}/corapanel-core /usr/local/bin/corapanel-core

# Create systemd service if systemd is available
if command -v systemctl &> /dev/null; then
    echo -e "${YELLOW}Creating systemd service...${NC}"
    ${SUDO} tee /etc/systemd/system/corapanel.service > /dev/null <<EOF
[Unit]
Description=CoraPanel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/local/bin/corapanel-core
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    ${SUDO} systemctl daemon-reload
    echo -e "${GREEN}Systemd service created${NC}"
    echo "You can start CoraPanel with: sudo systemctl start corapanel"
    echo "Enable auto-start with: sudo systemctl enable corapanel"
fi

# Cleanup
${SUDO} rm -f agent.tar.gz core.tar.gz

# Create default config if not exists
CONFIG_DIR="/etc/corapanel"
${SUDO} mkdir -p ${CONFIG_DIR}

if [ ! -f "${CONFIG_DIR}/config.yaml" ]; then
    echo -e "${YELLOW}Creating default configuration...${NC}"
    ${SUDO} tee ${CONFIG_DIR}/config.yaml > /dev/null <<EOF
server:
  port: 9999
  host: 0.0.0.0

auth:
  username: admin
  password: corapanel

database:
  type: sqlite
  path: /var/lib/corapanel/data.db

log:
  level: info
  file: /var/log/corapanel/app.log
EOF
    
    # Create required directories
    ${SUDO} mkdir -p /var/lib/corapanel
    ${SUDO} mkdir -p /var/log/corapanel
fi

echo -e "${GREEN}┌────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│     CoraPanel Installation Complete    │${NC}"
echo -e "${GREEN}└────────────────────────────────────────┘${NC}"
echo ""
echo -e "${GREEN}Version:${NC} ${ACTUAL_VERSION:-$VERSION}"
if [[ "$INSTALL_MODE" == "beta" ]]; then
    echo -e "${YELLOW}Mode:${NC} BETA (Testing version - not for production)${NC}"
fi
echo -e "${GREEN}Architecture:${NC} ${ARCH}"
echo -e "${GREEN}Installation Path:${NC} ${INSTALL_DIR}"
echo ""
echo -e "${YELLOW}Quick Start:${NC}"
if command -v systemctl &> /dev/null; then
    echo "  sudo systemctl start corapanel"
    echo "  sudo systemctl enable corapanel  # Auto-start on boot"
else
    echo "  corapanel-core"
fi
echo ""
echo -e "${YELLOW}Default Access:${NC}"
echo "  URL: http://localhost:9999"
echo "  Username: admin"
echo "  Password: corapanel"
echo ""
echo -e "${YELLOW}Configuration:${NC} ${CONFIG_DIR}/config.yaml"
echo -e "${YELLOW}Logs:${NC} /var/log/corapanel/"
echo ""
echo -e "${GREEN}Thank you for installing CoraPanel!${NC}"
