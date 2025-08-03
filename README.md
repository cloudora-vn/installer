# CoraPanel Installer

Official installer and binaries for CoraPanel.

## Quick Install

### Latest stable version
```bash
curl -sSL https://raw.githubusercontent.com/cloudora-vn/installer/main/install.sh | bash
```

### Beta version
```bash
curl -sSL https://raw.githubusercontent.com/cloudora-vn/installer/main/install.sh | bash -s beta
```

## Available Versions

- `latest`: Stable release from main branch
- `beta`: Development release from dev branch

## Binary Files

Binaries are stored in the `binaries/` directory:
- `binaries/latest/`: Latest stable binaries
- `binaries/beta/`: Beta binaries

## Manual Installation

1. Download the binaries from the `binaries/` directory
2. Extract and install:

```bash
tar -xzf corapanel-agent-linux-amd64.tar.gz
tar -xzf corapanel-core-linux-amd64.tar.gz
sudo mv corapanel-agent-linux-amd64 /usr/local/bin/corapanel-agent
sudo mv corapanel-core-linux-amd64 /usr/local/bin/corapanel-core
sudo chmod +x /usr/local/bin/corapanel-*
```

## Support

- Main Repository: https://github.com/cloudora-vn/corapanel
- Issues: https://github.com/cloudora-vn/corapanel/issues

## Build Info

- Latest build: 2025-08-03 08:38:16 UTC
- Latest commit: 2d2eb126dbd155de97aa88a47f0bc20e8c5ac03d
