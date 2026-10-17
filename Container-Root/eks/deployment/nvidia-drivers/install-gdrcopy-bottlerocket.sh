#!/bin/bash
set -euo pipefail

# GDRCopy Installer for Bottlerocket / EKS Auto Mode
# Builds gdrdrv.ko inside the container, then installs on the host via nsenter
#
# Required mounts:
#   /host-proc    -> host /proc
#   /host-modules -> host /lib/modules
#   /host-dev     -> host /dev

KERNEL_VERSION=$(cat /host-proc/version | awk '{print $3}')
NVIDIA_VERSION="${NVIDIA_VERSION:-580.178.04}"
GDRCOPY_VERSION="${GDRCOPY_VERSION:-2.6}"
BUILD_DIR="/tmp/gdrcopy-build"
CACHE_DIR="/host-modules/${KERNEL_VERSION}/gdrcopy-cache"

echo "🚀 GDRCopy Installer for Bottlerocket"
echo "  Kernel:   ${KERNEL_VERSION}"
echo "  NVIDIA:   ${NVIDIA_VERSION}"
echo "  GDRCopy:  ${GDRCOPY_VERSION}"
echo ""

# Check if already loaded
if grep -q gdrdrv /host-proc/modules && [ -c /host-dev/gdrdrv ]; then
    echo "✅ gdrdrv already loaded and /dev/gdrdrv exists — nothing to do"
    exit 0
fi

# Check for cached module from previous build
if [ -f "${CACHE_DIR}/gdrdrv.ko" ]; then
    echo "📦 Found cached gdrdrv.ko, skipping build..."
    GDRDRV_KO="${CACHE_DIR}/gdrdrv.ko"
else
    echo "📦 Installing build dependencies..."
    apt-get update -qq
    apt-get install -y -qq gcc make wget xz-utils bc flex bison \
        libelf-dev libssl-dev rsync cpio >/dev/null 2>&1
    echo "  ✅ Build deps installed"

    mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}"

    # Download kernel source
    echo ""
    echo "⬇️  Downloading kernel source ${KERNEL_VERSION}..."
    KERNEL_MAJOR=$(echo "${KERNEL_VERSION}" | cut -d'.' -f1)
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.xz" \
        -O kernel.tar.xz
    echo "  Extracting..."
    tar xf kernel.tar.xz
    rm kernel.tar.xz
    KDIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
    echo "  ✅ Kernel source ready"

    # Prepare kernel headers
    echo ""
    echo "🔧 Preparing kernel headers..."
    cd "${KDIR}"
    zcat /host-proc/config.gz > .config
    make olddefconfig >/dev/null 2>&1
    make modules_prepare >/dev/null 2>&1
    echo "  ✅ Kernel headers prepared"

    # Download NVIDIA headers (just nv-p2p.h — don't need the whole repo)
    echo ""
    echo "⬇️  Downloading NVIDIA headers (${NVIDIA_VERSION})..."
    NVIDIA_HDR_DIR="${BUILD_DIR}/nvidia-headers"
    mkdir -p "${NVIDIA_HDR_DIR}"
    # Try open-gpu-kernel-modules first, fall back to archived path
    wget -q "https://raw.githubusercontent.com/NVIDIA/open-gpu-kernel-modules/${NVIDIA_VERSION}/kernel-open/nvidia/nv-p2p.h" \
        -O "${NVIDIA_HDR_DIR}/nv-p2p.h" 2>/dev/null || \
    wget -q "https://raw.githubusercontent.com/NVIDIA/open-gpu-kernel-modules/${NVIDIA_VERSION}/src/nvidia/nv-p2p.h" \
        -O "${NVIDIA_HDR_DIR}/nv-p2p.h" 2>/dev/null || \
    { echo "❌ Failed to download nv-p2p.h for NVIDIA ${NVIDIA_VERSION}"; exit 1; }
    echo "  ✅ NVIDIA headers ready"

    # Download gdrcopy source
    echo ""
    echo "⬇️  Downloading GDRCopy ${GDRCOPY_VERSION}..."
    cd "${BUILD_DIR}"
    wget -q "https://github.com/NVIDIA/gdrcopy/archive/refs/tags/v${GDRCOPY_VERSION}.tar.gz" \
        -O gdrcopy.tar.gz
    tar xf gdrcopy.tar.gz
    rm gdrcopy.tar.gz
    echo "  ✅ GDRCopy source ready"

    # Build gdrdrv.ko
    echo ""
    echo "🔨 Building gdrdrv.ko..."
    cd "${BUILD_DIR}/gdrcopy-${GDRCOPY_VERSION}/src/gdrdrv"

    # Detect if NVIDIA driver is open-source (GPL)
    NVIDIA_IS_OPENSOURCE="y"  # EKS Auto Mode uses open GPU modules

    make \
        KDIR="${KDIR}" \
        NVIDIA_SRC_DIR="${NVIDIA_HDR_DIR}" \
        NVIDIA_IS_OPENSOURCE="${NVIDIA_IS_OPENSOURCE}" \
        HAVE_VM_FLAGS_SET=y \
        HAVE_PROC_OPS=y \
        KVER="${KERNEL_VERSION}" \
        -j$(nproc)

    if [ ! -f gdrdrv.ko ]; then
        echo "❌ Build failed — gdrdrv.ko not found"
        ls -la
        exit 1
    fi
    echo "  ✅ gdrdrv.ko built successfully ($(ls -lh gdrdrv.ko | awk '{print $5}'))"

    # Cache the module on the host for fast restart
    mkdir -p "${CACHE_DIR}"
    cp gdrdrv.ko "${CACHE_DIR}/gdrdrv.ko"
    # Also cache the nv-p2p-dummy module if built
    [ -f nv-p2p-dummy.ko ] && cp nv-p2p-dummy.ko "${CACHE_DIR}/nv-p2p-dummy.ko"

    GDRDRV_KO="${CACHE_DIR}/gdrdrv.ko"
    echo "  ✅ Cached at ${CACHE_DIR}"
fi

# Install module on the host
echo ""
echo "📥 Installing gdrdrv.ko on host..."
MODULE_DIR="/host-modules/${KERNEL_VERSION}/kernel/drivers/misc"
mkdir -p "${MODULE_DIR}"
cp "${GDRDRV_KO}" "${MODULE_DIR}/gdrdrv.ko"
# Also install nv-p2p-dummy if cached
[ -f "${CACHE_DIR}/nv-p2p-dummy.ko" ] && cp "${CACHE_DIR}/nv-p2p-dummy.ko" "${MODULE_DIR}/nv-p2p-dummy.ko"
echo "  ✅ Module copied to ${MODULE_DIR}"

# Load the module via nsenter into host namespace
echo ""
echo "🔌 Loading gdrdrv kernel module..."

# Unload if partially loaded
if grep -q gdrdrv /host-proc/modules; then
    echo "  Unloading existing module..."
    nsenter -t 1 -m -p -- rmmod gdrdrv 2>/dev/null || true
fi

# Update module deps and load
nsenter -t 1 -m -p -- depmod -a 2>/dev/null || true
nsenter -t 1 -m -p -- modprobe gdrdrv 2>/dev/null || \
    nsenter -t 1 -m -p -- insmod "/lib/modules/${KERNEL_VERSION}/kernel/drivers/misc/gdrdrv.ko" || \
    { echo "❌ Failed to load gdrdrv"; exit 1; }

# Wait for module init
sleep 2

if ! grep -q gdrdrv /host-proc/modules; then
    echo "❌ gdrdrv not in /proc/modules after loading"
    exit 1
fi
echo "  ✅ Module loaded"

# Create device node if needed
echo ""
echo "🔧 Setting up /dev/gdrdrv..."
if [ ! -c /host-dev/gdrdrv ]; then
    MAJOR=$(awk '$2=="gdrdrv" {print $1}' /host-proc/devices)
    if [ -n "${MAJOR}" ]; then
        # Create via nsenter so it appears on the host
        nsenter -t 1 -m -p -- mknod /dev/gdrdrv c "${MAJOR}" 0
        nsenter -t 1 -m -p -- chmod 666 /dev/gdrdrv
        echo "  ✅ Created /dev/gdrdrv (major=${MAJOR})"
    else
        echo "❌ gdrdrv loaded but no device entry in /proc/devices"
        cat /host-proc/devices | grep -i gdr || true
        exit 1
    fi
else
    nsenter -t 1 -m -p -- chmod 666 /dev/gdrdrv 2>/dev/null || true
    echo "  ✅ /dev/gdrdrv already exists"
fi

# Verify
echo ""
echo "🔍 Verification:"
echo "  Module: $(grep gdrdrv /host-proc/modules | awk '{print $1, "("$2" bytes)"}')"
echo "  Device: $(ls -la /host-dev/gdrdrv 2>&1)"
echo ""
echo "============================================"
echo "✅ GDRCopy installation complete!"
echo "============================================"
