#!/bin/bash
set -euo pipefail

# EFA Installer
# Requirements:
# - Root privileges
# - Internet access

echo "🚀 Starting EFA installation "
echo "================================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Version configuration
EFA_INSTALLER_VERSION=${EFA_INSTALLER_VERSION:-"latest"}
KERNEL_VERSION=$(uname -r)

# Detect kernel series for package naming
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f1)
KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f2)

echo "System Information:"
echo "  - OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  - Kernel: $KERNEL_VERSION"
echo "  - Kernel series: ${KERNEL_MAJOR}.${KERNEL_MINOR}"
echo "  - EFA installer version: $EFA_INSTALLER_VERSION"
echo ""

# Check if already installed
if [ -f /opt/amazon/efa/bin/fi_info ]; then
    echo "⚠️  EFA appears to be already installed"
    echo "   - FI Info: "
    echo "$(/opt/amazon/efa/bin/fi_info -p efa)"
    echo ""
    echo  "   Reinstall anyway? (y/N) "
    REINSTAL=${REINSTALL:-"N"}
    echo "$REINSTALL"
    echo ""
    if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
        echo "Exiting."
        exit 0
    fi
fi

cd /tmp
curl -fsSLO https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz
tar -xzf aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz
cd aws-efa-installer
./efa_installer.sh -y -g

