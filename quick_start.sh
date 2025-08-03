#!/bin/bash

osCheck=$(uname -a)
if [[ $osCheck =~ 'x86_64' ]]; then
    architecture="amd64"
elif [[ $osCheck =~ 'arm64' ]] || [[ $osCheck =~ 'aarch64' ]]; then
    architecture="arm64"
elif [[ $osCheck =~ 'armv7l' ]]; then
    architecture="armv7"
elif [[ $osCheck =~ 'ppc64le' ]]; then
    architecture="ppc64le"
elif [[ $osCheck =~ 's390x' ]]; then
    architecture="s390x"
else
    echo "The system architecture is not currently supported. Please refer to the official documentation to select a supported system."
    exit 1
fi

if [[ ! ${INSTALL_MODE} ]]; then
    INSTALL_MODE="latest"
else
    if [[ ${INSTALL_MODE} != "beta" && ${INSTALL_MODE} != "latest" ]]; then
        echo "Please enter the correct installation mode (beta or latest)"
        exit 1
    fi
fi

# Base URLs
BASE_URL="https://raw.githubusercontent.com/cloudora-vn/installer/refs/heads/main"
BINARIES_URL="${BASE_URL}/binaries/${INSTALL_MODE}"

# Download core and agent packages
CORE_PACKAGE="corapanel-core.tar.gz"
AGENT_PACKAGE="corapanel-agent.tar.gz"
CORE_DOWNLOAD_URL="${BINARIES_URL}/${CORE_PACKAGE}"
AGENT_DOWNLOAD_URL="${BINARIES_URL}/${AGENT_PACKAGE}"

# Check if installation files already exist
if [[ -f ${CORE_PACKAGE} ]] && [[ -f ${AGENT_PACKAGE} ]] && [[ -f install.sh ]]; then
    echo "Installation files already exist. Skip downloading."
    /bin/bash install.sh
    exit 0
fi

echo "Start downloading Corapanel from ${INSTALL_MODE} channel"

# Download corapanel-core
echo "Downloading corapanel-core..."
curl -LOk ${CORE_DOWNLOAD_URL}
if [[ ! -f ${CORE_PACKAGE} ]]; then
    echo "Failed to download corapanel-core"
    exit 1
fi

# Extract corapanel-core
tar zxf ${CORE_PACKAGE}
if [[ $? != 0 ]]; then
    echo "Failed to extract corapanel-core"
    rm -f ${CORE_PACKAGE}
    exit 1
fi

# Download corapanel-agent
echo "Downloading corapanel-agent..."
curl -LOk ${AGENT_DOWNLOAD_URL}
if [[ ! -f ${AGENT_PACKAGE} ]]; then
    echo "Failed to download corapanel-agent"
    exit 1
fi

# Extract corapanel-agent
tar zxf ${AGENT_PACKAGE}
if [[ $? != 0 ]]; then
    echo "Failed to extract corapanel-agent"
    rm -f ${AGENT_PACKAGE}
    exit 1
fi

# Download install.sh and other necessary files
echo "Downloading installation scripts..."
curl -LOk ${BASE_URL}/install.sh
curl -LOk ${BASE_URL}/corapctl

# Download service files
mkdir -p service_files
curl -o corapanel-core.service ${BASE_URL}/corapanel-core.service
curl -o corapanel-agent.service ${BASE_URL}/corapanel-agent.service

# Download language files
mkdir -p lang
for lang in en zh fa pt-BR ru; do
    curl -o lang/${lang}.sh ${BASE_URL}/lang/${lang}.sh
done

# Download GeoIP database
curl -LOk ${BASE_URL}/GeoIP.mmdb

# Make scripts executable
chmod +x install.sh corapctl corapanel-core corapanel-agent

# Run installation
/bin/bash install.sh