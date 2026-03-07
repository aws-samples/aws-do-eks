#!/bin/bash
set -euo pipefail

# Install NVIDIA Driver 580.126.09 and CUDA 13.0 on Amazon Linux 2023
# Intended for use on EKS g7e nodes (or any AL2023 x86_64 host with NVIDIA GPUs)
#
# This script is idempotent -- it checks each component individually and only
# installs what is missing or misconfigured. Safe to re-run multiple times.
#
# NOTE: EKS AMIs ship a kernel version whose kernel-devel package is not in
#       the public AL2023 repos, but the kernel headers ARE baked into the AMI
#       at /usr/src/kernels/$(uname -r). This script accounts for that by
#       skipping kernel-devel installation when the headers already exist.

DRIVER_VERSION="580.126.09"
CUDA_VERSION="13-0"
CUDA_VERSION_DOT="13.0"
KERNEL_VERSION=$(uname -r)
CONTAINER_RUNTIME="containerd"

# Track what needs to be done
NEEDS_KERNEL_HEADERS=false
NEEDS_BUILD_DEPS=false
NEEDS_REPO=false
NEEDS_MODULE_STREAM=false
NEEDS_DRIVER=false
NEEDS_CUDA=false
NEEDS_CONTAINER_TOOLKIT=false
NEEDS_CONTAINER_CONFIG=false
NEEDS_ENV_CONFIG=false
ANYTHING_CHANGED=false

echo "============================================="
echo " NVIDIA Driver ${DRIVER_VERSION} + CUDA ${CUDA_VERSION_DOT}"
echo " + NVIDIA Container Toolkit"
echo " Amazon Linux 2023 Installer"
echo "============================================="

# --- Preflight checks ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: This script must be run as root" >&2
    exit 1
fi

if ! grep -q 'Amazon Linux 2023' /etc/os-release 2>/dev/null; then
    echo "ERROR: This script is intended for Amazon Linux 2023 only" >&2
    exit 1
fi

ARCH=$(uname -m)
if [[ "${ARCH}" != "x86_64" ]]; then
    echo "ERROR: This script supports x86_64 only (detected: ${ARCH})" >&2
    exit 1
fi

# =============================================================================
# Detection phase -- figure out what's already installed
# =============================================================================
echo ""
echo "Checking installed components..."

# 1. Kernel headers
KERNEL_HEADERS_DIR="/usr/src/kernels/${KERNEL_VERSION}"
if [[ -d "${KERNEL_HEADERS_DIR}" ]]; then
    echo "  [OK] Kernel headers present at ${KERNEL_HEADERS_DIR}"
else
    echo "  [MISSING] Kernel headers for ${KERNEL_VERSION}"
    NEEDS_KERNEL_HEADERS=true
fi

# 2. Build dependencies
if command -v gcc &>/dev/null && command -v make &>/dev/null; then
    echo "  [OK] Build dependencies (gcc, make)"
else
    echo "  [MISSING] Build dependencies"
    NEEDS_BUILD_DEPS=true
fi

# 3. CUDA repo
if [[ -f /etc/yum.repos.d/cuda-amzn2023.repo ]]; then
    echo "  [OK] NVIDIA CUDA repository"
else
    echo "  [MISSING] NVIDIA CUDA repository"
    NEEDS_REPO=true
fi

# 4. DNF module stream
if dnf module list --enabled nvidia-driver 2>/dev/null | grep -q "580-open"; then
    echo "  [OK] DNF module stream nvidia-driver:580-open"
else
    echo "  [MISSING] DNF module stream nvidia-driver:580-open not enabled"
    NEEDS_MODULE_STREAM=true
fi

# 5. NVIDIA driver packages
if rpm -q "nvidia-driver" &>/dev/null; then
    INSTALLED_DRIVER=$(rpm -q --queryformat '%{EPOCH}:%{VERSION}' nvidia-driver 2>/dev/null || true)
    if [[ "${INSTALLED_DRIVER}" == "3:${DRIVER_VERSION}" ]]; then
        echo "  [OK] NVIDIA driver ${DRIVER_VERSION}"
    else
        echo "  [WRONG VERSION] NVIDIA driver installed: ${INSTALLED_DRIVER}, need 3:${DRIVER_VERSION}"
        NEEDS_DRIVER=true
    fi
else
    echo "  [MISSING] NVIDIA driver"
    NEEDS_DRIVER=true
fi

# 6. CUDA toolkit
if rpm -q "cuda-toolkit-${CUDA_VERSION}" &>/dev/null; then
    echo "  [OK] CUDA toolkit ${CUDA_VERSION_DOT}"
else
    echo "  [MISSING] CUDA toolkit ${CUDA_VERSION_DOT}"
    NEEDS_CUDA=true
fi

# 7. NVIDIA Container Toolkit
if command -v nvidia-ctk &>/dev/null; then
    echo "  [OK] NVIDIA Container Toolkit ($(nvidia-ctk --version 2>/dev/null | head -1 || echo 'unknown'))"
else
    echo "  [MISSING] NVIDIA Container Toolkit"
    NEEDS_CONTAINER_TOOLKIT=true
fi

# 8. Containerd NVIDIA runtime configuration
if grep -rq "nvidia-container-runtime" /etc/containerd/ 2>/dev/null; then
    echo "  [OK] Containerd NVIDIA runtime configured"
else
    echo "  [MISSING] Containerd NVIDIA runtime configuration"
    NEEDS_CONTAINER_CONFIG=true
fi

# 9. Environment configuration
if [[ -f /etc/profile.d/cuda.sh ]] && [[ -f /etc/modules-load.d/nvidia.conf ]]; then
    echo "  [OK] Environment configuration (cuda.sh, nvidia.conf)"
else
    echo "  [MISSING] Environment configuration"
    NEEDS_ENV_CONFIG=true
fi

# --- Check if everything is already done ---
if ! ${NEEDS_KERNEL_HEADERS} && ! ${NEEDS_BUILD_DEPS} && ! ${NEEDS_REPO} \
    && ! ${NEEDS_MODULE_STREAM} && ! ${NEEDS_DRIVER} && ! ${NEEDS_CUDA} \
    && ! ${NEEDS_CONTAINER_TOOLKIT} && ! ${NEEDS_CONTAINER_CONFIG} \
    && ! ${NEEDS_ENV_CONFIG}; then
    echo ""
    echo "All components are already installed and configured."
    if command -v nvidia-smi &>/dev/null; then
        if ! nvidia-smi &>/dev/null; then
            echo "Driver installed but not loaded (version mismatch). Rebooting..."
            reboot
        fi
        nvidia-smi
    fi
    exit 0
fi

echo ""
echo "============================================="
echo " Installing missing components..."
echo "============================================="

# =============================================================================
# Step 1: Kernel headers and build dependencies
# =============================================================================
if ${NEEDS_KERNEL_HEADERS}; then
    echo ""
    echo "[1/7] Installing kernel headers..."
    if ! dnf install -y "kernel-devel-${KERNEL_VERSION}" 2>/dev/null; then
        echo "ERROR: kernel-devel-${KERNEL_VERSION} is not available and kernel headers" >&2
        echo "       are not present at ${KERNEL_HEADERS_DIR}." >&2
        echo "       Cannot compile NVIDIA kernel module." >&2
        exit 1
    fi
    ANYTHING_CHANGED=true
else
    echo ""
    echo "[1/7] Kernel headers -- skipped (already present)"
fi

# Ensure the build symlink exists
if [[ ! -L "/lib/modules/${KERNEL_VERSION}/build" ]]; then
    ln -sf "${KERNEL_HEADERS_DIR}" "/lib/modules/${KERNEL_VERSION}/build"
fi

if ${NEEDS_BUILD_DEPS}; then
    echo "  Installing build dependencies..."
    dnf install -y gcc make elfutils-libelf-devel
    ANYTHING_CHANGED=true
fi

# =============================================================================
# Step 2: NVIDIA CUDA repository and module stream
# =============================================================================
if ${NEEDS_REPO} || ${NEEDS_MODULE_STREAM}; then
    echo ""
    echo "[2/7] Configuring NVIDIA CUDA repository..."

    if ${NEEDS_REPO}; then
        dnf config-manager --add-repo \
            https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
        rpm --import https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/D42D0685.pub 2>/dev/null || true
    fi

    if ${NEEDS_MODULE_STREAM}; then
        echo "  Resetting nvidia-driver module streams..."
        dnf module reset nvidia-driver -y 2>/dev/null || true
        echo "  Enabling nvidia-driver:580-open module stream..."
        dnf module enable nvidia-driver:580-open -y
    fi

    dnf clean all
    dnf makecache
    ANYTHING_CHANGED=true
else
    echo ""
    echo "[2/7] NVIDIA CUDA repository -- skipped (already configured)"
fi

# =============================================================================
# Step 3: Remove conflicting drivers (only if we need to install/change driver)
# =============================================================================
if ${NEEDS_DRIVER}; then
    echo ""
    echo "[3/7] Removing any conflicting NVIDIA packages..."
    dnf remove -y nvidia-driver nvidia-driver-cuda nvidia-driver-libs \
        nvidia-driver-devel nvidia-kmod-common 2>/dev/null || true
else
    echo ""
    echo "[3/7] Driver cleanup -- skipped (correct version installed)"
fi

# =============================================================================
# Step 4: NVIDIA driver and CUDA toolkit
# =============================================================================
if ${NEEDS_DRIVER}; then
    echo ""
    echo "[4/7] Installing NVIDIA driver ${DRIVER_VERSION}..."

    # Ensure repo and module stream are ready (may have been skipped above)
    if [[ ! -f /etc/yum.repos.d/cuda-amzn2023.repo ]]; then
        dnf config-manager --add-repo \
            https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/cuda-amzn2023.repo
        rpm --import https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/D42D0685.pub 2>/dev/null || true
    fi
    if ! dnf module list --enabled nvidia-driver 2>/dev/null | grep -q "580-open"; then
        dnf module reset nvidia-driver -y 2>/dev/null || true
        dnf module enable nvidia-driver:580-open -y
        dnf clean all
        dnf makecache
    fi

    dnf module install -y nvidia-driver:580-open/default \
        --setopt=install_weak_deps=False

    dnf install -y \
        "nvidia-driver-3:${DRIVER_VERSION}-1.amzn2023" \
        "nvidia-driver-cuda-3:${DRIVER_VERSION}-1.amzn2023" \
        "nvidia-driver-cuda-libs-3:${DRIVER_VERSION}-1.amzn2023" \
        "nvidia-driver-libs-3:${DRIVER_VERSION}-1.amzn2023" \
        "nvidia-kmod-common-3:${DRIVER_VERSION}-1.amzn2023" \
        "kmod-nvidia-open-dkms-3:${DRIVER_VERSION}-1.amzn2023" \
        --allowerasing
    ANYTHING_CHANGED=true
else
    echo ""
    echo "[4/7] NVIDIA driver -- skipped (${DRIVER_VERSION} already installed)"
fi

if ${NEEDS_CUDA}; then
    echo ""
    echo "  Installing CUDA toolkit ${CUDA_VERSION_DOT}..."
    dnf install -y "cuda-toolkit-${CUDA_VERSION}"
    ANYTHING_CHANGED=true
else
    echo "  CUDA toolkit -- skipped (already installed)"
fi

# =============================================================================
# Step 5: NVIDIA Container Toolkit
# =============================================================================
if ${NEEDS_CONTAINER_TOOLKIT}; then
    echo ""
    echo "[5/7] Installing NVIDIA Container Toolkit..."

    if [[ ! -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]]; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
            | tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
    fi

    dnf install -y nvidia-container-toolkit
    ANYTHING_CHANGED=true
    # New toolkit install always needs containerd reconfiguration
    NEEDS_CONTAINER_CONFIG=true
else
    echo ""
    echo "[5/7] NVIDIA Container Toolkit -- skipped (already installed)"
fi

# =============================================================================
# Step 6: Configure containerd with NVIDIA runtime
# =============================================================================
if ${NEEDS_CONTAINER_CONFIG}; then
    echo ""
    echo "[6/7] Configuring NVIDIA Container Toolkit for ${CONTAINER_RUNTIME}..."

    nvidia-ctk runtime configure --runtime="${CONTAINER_RUNTIME}"
    nvidia-ctk config --set nvidia-container-runtime.log-level=info --in-place 2>/dev/null || true

    echo "  Containerd NVIDIA runtime configured (will take effect on reboot)"
    ANYTHING_CHANGED=true
else
    echo ""
    echo "[6/7] Containerd NVIDIA runtime -- skipped (already configured)"
fi

# =============================================================================
# Step 7: Environment configuration
# =============================================================================
if ${NEEDS_ENV_CONFIG}; then
    echo ""
    echo "[7/7] Configuring environment..."

    cat > /etc/profile.d/cuda.sh << 'ENVEOF'
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENVEOF
    chmod 644 /etc/profile.d/cuda.sh

    cat > /etc/modules-load.d/nvidia.conf << 'MODEOF'
nvidia
nvidia_uvm
nvidia_drm
MODEOF
    ANYTHING_CHANGED=true
else
    echo ""
    echo "[7/7] Environment configuration -- skipped (already configured)"
fi

# Always ensure kernel modules and persistenced are active
modprobe nvidia 2>/dev/null || true
modprobe nvidia_uvm 2>/dev/null || true
modprobe nvidia_drm 2>/dev/null || true
systemctl enable nvidia-persistenced 2>/dev/null || true
systemctl start nvidia-persistenced 2>/dev/null || true

# =============================================================================
# Verification
# =============================================================================
echo ""
echo "============================================="
echo " Installation Complete"
echo "============================================="

export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

if command -v nvidia-smi &>/dev/null; then
    echo ""
    nvidia-smi 2>/dev/null || echo "NOTE: nvidia-smi failed -- driver may need a reboot to load"
fi

echo ""
echo "CUDA compiler version:"
nvcc --version 2>/dev/null || echo "  nvcc not found - source /etc/profile.d/cuda.sh or reboot"

echo ""
echo "Container toolkit verification:"
nvidia-ctk --version 2>/dev/null || echo "  nvidia-ctk not found"

echo ""
echo "Containerd NVIDIA runtime check:"
if grep -rq "nvidia-container-runtime" /etc/containerd/ 2>/dev/null; then
    echo "  NVIDIA runtime is configured in containerd"
else
    echo "  WARNING: NVIDIA runtime not found in containerd config"
fi

if ${ANYTHING_CHANGED}; then
    echo ""
    echo "Components were installed/changed. Rebooting now..."
    reboot
else
    echo ""
    echo "No changes were made."
fi
