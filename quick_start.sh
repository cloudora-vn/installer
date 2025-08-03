#!/bin/bash

# CoraPanel Quick Start Script
# This script automatically downloads and installs the latest version of CoraPanel

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="cloudora-vn/installer"
# Check if INSTALL_MODE is already set from environment
if [[ -z "${INSTALL_MODE}" ]]; then
    INSTALL_MODE="latest"  # Default to latest if not set
fi
CUSTOM_VERSION=${CUSTOM_VERSION:-""}

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║        CoraPanel Quick Start          ║"
echo "║       Powered by Cloudora VN          ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Parse command line arguments (override environment if provided)
for arg in "$@"; do
    case $arg in
        beta|--beta)
            INSTALL_MODE="beta"
            ;;
        latest|--latest)
            INSTALL_MODE="latest"
            ;;
        --version=*)
            CUSTOM_VERSION="${arg#*=}"
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  beta, --beta       Install beta version"
            echo "  latest, --latest   Install latest stable version (default)"
            echo "  --version=VERSION  Install specific version"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  INSTALL_MODE=beta  Install beta version"
            echo "  INSTALL_MODE=latest Install latest stable version"
            echo ""
            echo "Examples:"
            echo "  # Install beta using environment variable:"
            echo "  curl -fsSL $GITHUB_REPO/quick_start.sh | INSTALL_MODE=beta bash"
            echo ""
            echo "  # Install beta using argument:"
            echo "  curl -fsSL $GITHUB_REPO/quick_start.sh | bash -s beta"
            exit 0
            ;;
    esac
done

# Check install mode
if [[ "$INSTALL_MODE" == "beta" ]]; then
    echo -e "${YELLOW}⚠️  BETA MODE: Installing testing version${NC}"
    echo -e "${YELLOW}   Not recommended for production use${NC}"
    echo ""
elif [[ "$INSTALL_MODE" != "latest" ]]; then
    echo -e "${RED}Invalid INSTALL_MODE. Use 'latest' or 'beta'${NC}"
    exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   SUDO=""
else
   SUDO="sudo"
   echo -e "${YELLOW}[!] This script requires sudo privileges${NC}"
fi

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
        OS_NAME=$(lsb_release -sd)
    else
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(uname -r)
        OS_NAME="$OS $OS_VERSION"
    fi
    
    echo -e "${GREEN}[✓] Detected OS: ${OS_NAME}${NC}"
}

# Detect architecture
detect_architecture() {
    local arch=$(uname -m)
    
    case ${arch} in
        x86_64)
            ARCHITECTURE="amd64"
            ;;
        aarch64|arm64)
            ARCHITECTURE="arm64"
            ;;
        armv7l|armv7)
            ARCHITECTURE="armv7"
            ;;
        armv6l|armv6)
            ARCHITECTURE="armv6"
            ;;
        i686|i386)
            ARCHITECTURE="386"
            ;;
        ppc64le)
            ARCHITECTURE="ppc64le"
            ;;
        s390x)
            ARCHITECTURE="s390x"
            ;;
        *)
            echo -e "${RED}[✗] Unsupported architecture: ${arch}${NC}"
            echo "Please refer to the official documentation for supported architectures"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}[✓] Detected Architecture: ${ARCHITECTURE}${NC}"
}

# Check system requirements
check_requirements() {
    echo -e "${YELLOW}[i] Checking system requirements...${NC}"
    
    # Check minimum RAM (512MB)
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $total_ram -lt 512 ]]; then
        echo -e "${RED}[✗] Insufficient RAM. Minimum 512MB required${NC}"
        exit 1
    fi
    
    # Check available disk space (1GB)
    local available_space=$(df / | awk 'NR==2 {print int($4/1024)}')
    if [[ $available_space -lt 1024 ]]; then
        echo -e "${YELLOW}[!] Warning: Low disk space (${available_space}MB available)${NC}"
    fi
    
    # Check required commands
    local required_commands=("curl" "tar" "systemctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${YELLOW}[!] Installing missing dependency: $cmd${NC}"
            install_dependency $cmd
        fi
    done
    
    echo -e "${GREEN}[✓] System requirements check passed${NC}"
}

# Install missing dependencies
install_dependency() {
    local package=$1
    
    case ${OS} in
        ubuntu|debian)
            ${SUDO} apt-get update > /dev/null 2>&1
            ${SUDO} apt-get install -y $package > /dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            ${SUDO} yum install -y $package > /dev/null 2>&1
            ;;
        opensuse*)
            ${SUDO} zypper install -y $package > /dev/null 2>&1
            ;;
        arch|manjaro)
            ${SUDO} pacman -S --noconfirm $package > /dev/null 2>&1
            ;;
        alpine)
            ${SUDO} apk add --no-cache $package > /dev/null 2>&1
            ;;
        *)
            echo -e "${RED}[✗] Cannot auto-install $package on ${OS}${NC}"
            echo "Please install $package manually and re-run this script"
            exit 1
            ;;
    esac
}

# Get latest version from GitHub
get_latest_version() {
    echo -e "${YELLOW}[i] Fetching version information...${NC}"
    
    if [[ -n "$CUSTOM_VERSION" ]]; then
        VERSION=$CUSTOM_VERSION
        echo -e "${GREEN}[✓] Using custom version: ${VERSION}${NC}"
    elif [[ "$INSTALL_MODE" == "beta" ]]; then
        # For beta, always use beta channel (no version.txt needed)
        VERSION="beta"
        echo -e "${YELLOW}[!] Using BETA channel for testing${NC}"
        echo -e "${YELLOW}    Note: Beta version may be unstable${NC}"
    else
        # For latest stable version - use beta files for now until we have stable releases
        # This is temporary until we have proper stable releases
        VERSION="latest"
        echo -e "${GREEN}[✓] Using latest stable channel${NC}"
        echo -e "${YELLOW}    Note: Using beta builds as stable (temporary)${NC}"
    fi
}

# Download and install
download_and_install() {
    local temp_dir="/tmp/corapanel-install-$$"
    mkdir -p $temp_dir
    cd $temp_dir
    
    echo -e "${YELLOW}[i] Downloading installation script...${NC}"
    
    # Download the install.sh script
    local install_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/install.sh"
    
    if ! curl -fsSL -o install.sh "$install_url" 2>/dev/null; then
        echo -e "${RED}[✗] Failed to download installation script${NC}"
        echo "URL: $install_url"
        cleanup_and_exit 1
    fi
    
    # Make it executable
    chmod +x install.sh
    
    echo -e "${YELLOW}[i] Starting installation...${NC}"
    echo ""
    
    # Run the installation script with version parameter
    if [[ "$INSTALL_MODE" == "beta" ]]; then
        bash install.sh beta
    elif [[ "$VERSION" == "latest" ]]; then
        bash install.sh latest
    else
        bash install.sh "$VERSION"
    fi
    
    local install_result=$?
    
    # Cleanup
    cd /
    rm -rf $temp_dir
    
    return $install_result
}

# Cleanup function
cleanup_and_exit() {
    local exit_code=${1:-0}
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        rm -rf $temp_dir
    fi
    exit $exit_code
}

# Post-installation tasks
post_installation() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}[✓] Installation completed successfully!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo ""
    
    # Check if service is running
    if command -v systemctl &> /dev/null; then
        if systemctl is-active --quiet corapanel; then
            echo -e "${GREEN}[✓] CoraPanel service is running${NC}"
        else
            echo -e "${YELLOW}[i] Start CoraPanel with:${NC}"
            echo "    sudo systemctl start corapanel"
        fi
    fi
    
    # Show access information
    echo ""
    echo -e "${BLUE}Access Information:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get actual IP addresses
    local ips=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -3)
    if [[ -n "$ips" ]]; then
        echo -e "${YELLOW}Access URLs:${NC}"
        echo "$ips" | while read ip; do
            echo "  • http://$ip:9999"
        done
    else
        echo -e "${YELLOW}Access URL:${NC} http://localhost:9999"
    fi
    
    echo ""
    echo -e "${YELLOW}Default Credentials:${NC}"
    echo "  Username: admin"
    echo "  Password: corapanel"
    echo ""
    echo -e "${YELLOW}Documentation:${NC} https://github.com/${GITHUB_REPO}"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
}

# Error handler
error_handler() {
    echo ""
    echo -e "${RED}[✗] Installation failed!${NC}"
    echo -e "${YELLOW}[i] Please check the error messages above${NC}"
    echo -e "${YELLOW}[i] For help, visit: https://github.com/${GITHUB_REPO}/issues${NC}"
    cleanup_and_exit 1
}

# Set up error handling
trap error_handler ERR

# Main installation flow
main() {
    echo -e "${YELLOW}[i] Starting CoraPanel Quick Installation${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # System detection
    detect_os
    detect_architecture
    
    # Requirements check
    check_requirements
    
    # Get version
    get_latest_version
    
    # Confirm installation
    echo ""
    if [[ "$INSTALL_MODE" == "beta" ]]; then
        echo -e "${YELLOW}[?] Ready to install CoraPanel BETA ${VERSION} for ${ARCHITECTURE}${NC}"
        echo -e "${RED}    ⚠️  Beta version may be unstable${NC}"
    else
        echo -e "${YELLOW}[?] Ready to install CoraPanel ${VERSION} for ${ARCHITECTURE}${NC}"
    fi
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[i] Installation cancelled${NC}"
        exit 0
    fi
    
    # Download and install
    if download_and_install; then
        post_installation
    else
        error_handler
    fi
}

# Run main function
main "$@"