#!/bin/bash
set -e

# CoraPanel Quick Installer
VERSION=${1:-latest}
BASE_URL="https://raw.githubusercontent.com/cloudora-vn/installer/main/binaries"

echo "Installing CoraPanel (${VERSION})..."

# Detect architecture
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        ARCH="amd64"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}"
        exit 1
        ;;
esac

# Create installation directory
sudo mkdir -p /opt/corapanel
cd /opt/corapanel

# Download binaries
echo "Downloading CoraPanel Agent..."
sudo curl -L -o agent.tar.gz "${BASE_URL}/${VERSION}/corapanel-agent-linux-${ARCH}.tar.gz"

echo "Downloading CoraPanel Core..."
sudo curl -L -o core.tar.gz "${BASE_URL}/${VERSION}/corapanel-core-linux-${ARCH}.tar.gz"

# Extract
sudo tar -xzf agent.tar.gz
sudo tar -xzf core.tar.gz

# Set permissions
sudo chmod +x corapanel-agent-linux-${ARCH}
sudo chmod +x corapanel-core-linux-${ARCH}

# Create symlinks
sudo ln -sf /opt/corapanel/corapanel-agent-linux-${ARCH} /usr/local/bin/corapanel-agent
sudo ln -sf /opt/corapanel/corapanel-core-linux-${ARCH} /usr/local/bin/corapanel-core

# Cleanup
sudo rm -f agent.tar.gz core.tar.gz

echo "CoraPanel installed successfully!"
echo "Version: ${VERSION}"
echo ""
echo "Start CoraPanel with:"
echo "  corapanel-core"
echo ""
echo "Default access:"
echo "  URL: http://localhost:9999"
echo "  Username: admin"
echo "  Password: corapanel"
