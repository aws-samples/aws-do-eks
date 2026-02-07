#!/bin/bash
set -euo pipefail

# GDRCopy Installer for Amazon Linux 2023 (no CUDA dependency)
# This version handles kernel 6.12+ naming and builds without CUDA properly
#
# Usage: sudo bash install_gdrcopy_al2023_v2.sh
#
# Requirements:
# - Amazon Linux 2023
# - Root privileges
# - Internet access

echo "🚀 Starting GDRCopy installation for Amazon Linux 2023 (v2)"
echo "================================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Version configuration
GDRCOPY_VERSION=${GDRCOPY_VERSION:-"2.4.1"}
KERNEL_VERSION=$(uname -r)
BUILD_DIR="/tmp/gdrcopy-build-$$"

# Detect kernel series for package naming
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f1)
KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f2)

echo "System Information:"
echo "  - OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "  - Kernel: $KERNEL_VERSION"
echo "  - Kernel series: ${KERNEL_MAJOR}.${KERNEL_MINOR}"
echo "  - GDRCopy version: $GDRCOPY_VERSION"
echo ""

# Check if already installed
if [ -c /dev/gdrdrv ] && lsmod | grep -q gdrdrv; then
    echo "⚠️  GDRCopy appears to be already installed"
    echo "   - Kernel module: $(lsmod | grep gdrdrv | awk '{print $1}')"
    echo "   - Device node: $(ls -la /dev/gdrdrv)"
    echo "   Reinstall anyway? (y/N) "
    REINSTALL=${REINSTALL:-"N"}
    echo "$REINSTALL"
    echo
    if [[ ! $REINSTALL =~ ^[Yy]$ ]]; then
        echo "Exiting."
        exit 0
    fi
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Determine correct kernel package names for Amazon Linux 2023
# Kernel 6.12+ uses kernel6.12-devel pattern
# Kernel 6.1 uses kernel-devel pattern
if [ "$KERNEL_MAJOR" -eq 6 ] && [ "$KERNEL_MINOR" -ge 12 ]; then
    KERNEL_PKG_PREFIX="kernel${KERNEL_MAJOR}.${KERNEL_MINOR}"
    KERNEL_DEVEL_PKG="${KERNEL_PKG_PREFIX}-devel-${KERNEL_VERSION}"
    KERNEL_HEADERS_PKG="${KERNEL_PKG_PREFIX}-headers-${KERNEL_VERSION}"
    echo "Using kernel 6.12+ package naming: ${KERNEL_PKG_PREFIX}-*"
else
    KERNEL_DEVEL_PKG="kernel-devel-${KERNEL_VERSION}"
    KERNEL_HEADERS_PKG="kernel-headers-${KERNEL_VERSION}"
    echo "Using standard kernel package naming: kernel-*"
fi

# Install build dependencies
echo ""
echo "📦 Installing build dependencies..."
dnf install -y \
    "${KERNEL_DEVEL_PKG}" \
    "${KERNEL_HEADERS_PKG}" \
    gcc \
    gcc-c++ \
    make \
    git \
    elfutils-libelf-devel \
    bc

echo "✅ Dependencies installed"
echo ""

# Download GDRCopy source
echo "⬇️  Downloading GDRCopy ${GDRCOPY_VERSION}..."
wget -q --show-progress https://github.com/NVIDIA/gdrcopy/archive/refs/tags/v${GDRCOPY_VERSION}.tar.gz
tar xzf v${GDRCOPY_VERSION}.tar.gz
cd gdrcopy-${GDRCOPY_VERSION}

echo "✅ Source downloaded"
echo ""

# Build kernel module ONLY (no CUDA needed for this)
echo "🔨 Building GDRCopy kernel module (without CUDA)..."
cd src/gdrdrv

# Clean any previous builds
make clean 2>/dev/null || true

# Build kernel module only
echo "   Building gdrdrv.ko kernel module..."
make -j$(nproc)

# gdrdrv.ko is built in the gdrdrv/ subfolder
if [ ! -f gdrdrv.ko ]; then
    echo "❌ ERROR: Kernel module build failed - gdrdrv.ko not found"
    exit 1
fi

echo "✅ Kernel module built: $(ls -lh gdrdrv.ko)"
echo ""

# Install kernel module
echo "📥 Installing kernel module..."

# Determine kernel module directory
KMOD_DIR="/lib/modules/${KERNEL_VERSION}/kernel/drivers/misc"
mkdir -p "$KMOD_DIR"

# Copy kernel module
cp gdrdrv.ko "$KMOD_DIR/"
echo "   Copied gdrdrv.ko to $KMOD_DIR"

# Update module dependencies
depmod -a
echo "   Updated module dependencies"

echo "✅ Kernel module installed"
echo ""

# Build and install userspace library (doesn't need CUDA)
# Note: We're still in src/ directory where library was already built by 'make'
echo "📦 Installing userspace library..."

cd ..
make clean
make -j$(nproc)

# The library is built as libgdrapi.so.MAJOR.MINOR (e.g., libgdrapi.so.2.4)
# Find the actual versioned library file that was built
LIBGDRAPI_FULL=$(ls libgdrapi.so.*.* 2>/dev/null | grep -v '.so.2$' | head -1)

if [ -n "$LIBGDRAPI_FULL" ] && [ -f "$LIBGDRAPI_FULL" ]; then
    echo "   Found library: $LIBGDRAPI_FULL"
    echo "   Installing libgdrapi.so..."
    cp "$LIBGDRAPI_FULL" /usr/lib64/
    cd /usr/lib64
    # Extract version for symlinks (e.g., "2.4" from "libgdrapi.so.2.4")
    LIB_VERSION=$(echo "$LIBGDRAPI_FULL" | sed 's/libgdrapi.so.//')
    LIB_MAJOR=$(echo "$LIB_VERSION" | cut -d'.' -f1)
    ln -sf "$LIBGDRAPI_FULL" "libgdrapi.so.${LIB_MAJOR}"
    ln -sf "libgdrapi.so.${LIB_MAJOR}" libgdrapi.so
    ldconfig
    echo "✅ Userspace library installed ($LIBGDRAPI_FULL)"
else
    echo "⚠️  Userspace library not built (optional)"
fi

echo ""

# Load kernel module
echo "🔌 Loading gdrdrv kernel module..."

# Unload if already loaded
if lsmod | grep -q gdrdrv; then
    echo "   Unloading existing module..."
    rmmod gdrdrv || true
fi

# Load module
modprobe gdrdrv

# Wait for module to initialize
sleep 2

echo "✅ Module loaded"
echo ""

# Create device node if not exist
echo "🔧 Setting up device node..."

if [ ! -c /dev/gdrdrv ]; then
    MAJOR=$(awk '$2=="gdrdrv" {print $1}' /proc/devices)
    if [ -n "$MAJOR" ]; then
        mknod /dev/gdrdrv c $MAJOR 0
        chmod 666 /dev/gdrdrv
        echo "   ✅ Created /dev/gdrdrv (major=$MAJOR, mode=0666)"
    else
        echo "   ❌ ERROR: gdrdrv module loaded but no device entry in /proc/devices"
        lsmod | grep gdrdrv
        dmesg | tail -20
        exit 1
    fi
else
    chmod 666 /dev/gdrdrv
    echo "   ✅ Device node already exists: $(ls -la /dev/gdrdrv)"
fi

echo ""

# Verify installation
echo "🔍 Verifying GDRCopy installation..."
echo ""

ERRORS=0

# Check kernel module
if lsmod | grep -q gdrdrv; then
    MODULE_INFO=$(lsmod | grep gdrdrv)
    echo "   ✅ gdrdrv kernel module loaded"
    echo "      $MODULE_INFO"
else
    echo "   ❌ ERROR: gdrdrv module not loaded"
    ERRORS=$((ERRORS + 1))
fi

# Check device node
if [ -c /dev/gdrdrv ]; then
    DEV_INFO=$(ls -la /dev/gdrdrv)
    echo "   ✅ /dev/gdrdrv device exists"
    echo "      $DEV_INFO"
else
    echo "   ❌ ERROR: /dev/gdrdrv device missing"
    ERRORS=$((ERRORS + 1))
fi

# Check library
if [ -f /usr/lib64/libgdrapi.so ]; then
    echo "   ✅ libgdrapi.so installed"
    ls -la /usr/lib64/libgdrapi.so* | sed 's/^/      /'
else
    echo "   ⚠️  libgdrapi.so not found (optional)"
fi

# Check kernel module location
if [ -f "$KMOD_DIR/gdrdrv.ko" ]; then
    echo "   ✅ Kernel module installed at $KMOD_DIR/gdrdrv.ko"
else
    echo "   ⚠️  Warning: Kernel module not in expected location"
fi

echo ""

if [ $ERRORS -gt 0 ]; then
    echo "❌ Installation completed with $ERRORS error(s)"
    exit 1
fi

# Make module load on boot
echo "🔄 Configuring automatic loading on boot..."
echo "gdrdrv" > /etc/modules-load.d/gdrdrv.conf
echo "   ✅ Created /etc/modules-load.d/gdrdrv.conf"

# Set permissions permanently via udev
echo "🔒 Setting device permissions via udev..."
cat > /etc/udev/rules.d/99-gdrdrv.rules <<EOF
KERNEL=="gdrdrv", MODE="0666"
EOF
echo "   ✅ Created /etc/udev/rules.d/99-gdrdrv.rules"

# Reload udev rules
udevadm control --reload-rules 2>/dev/null || true

echo ""
echo "================================================================"
echo "✅ GDRCopy installation complete!"
echo "================================================================"
echo ""
echo "Summary:"
echo "  - Kernel: $KERNEL_VERSION"
echo "  - Module: $(lsmod | grep gdrdrv | awk '{print $1, "("$2" bytes)"}')"
echo "  - Device: /dev/gdrdrv (mode=$(stat -c %a /dev/gdrdrv))"
echo "  - Location: $KMOD_DIR/gdrdrv.ko"
if [ -f /usr/lib64/libgdrapi.so ]; then
    echo "  - Library: $(ls /usr/lib64/libgdrapi.so.*.* 2>/dev/null | head -1)"
fi
echo "  - Auto-load: Enabled via /etc/modules-load.d/gdrdrv.conf"
echo ""
echo "Next steps:"
echo "  1. Verify with: lsmod | grep gdrdrv && ls -la /dev/gdrdrv"
echo "  2. Enable in training: FI_EFA_USE_DEVICE_RDMA=1"
echo "  3. Check NCCL logs for: 'GDRDMA'"
echo ""
echo "To verify GDR is working in NCCL, look for this in training logs:"
echo "  'NCCL INFO Channel 00/XX : ... via NET/Libfabric/0/GDRDMA'"
echo ""

# Cleanup build directory
echo "🧹 Cleaning up build directory..."
cd /
rm -rf "$BUILD_DIR"
echo "   ✅ Removed $BUILD_DIR"
echo ""

echo "Installation complete! GDRCopy is now ready to use."
echo ""
echo "Quick test (if you have NVIDIA GPUs):"
echo "  nvidia-smi -L"
echo "  lsmod | grep gdrdrv"
echo "  ls -la /dev/gdrdrv"

