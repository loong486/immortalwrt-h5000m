#!/bin/bash
# =================================================================
# DIY script part 2 (After feeds install)
# Description: Clone plugins, apply patches, fix feeds precedence
# =================================================================

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Clone Hiveton H5000M Fan Control LuCI App
rm -rf package/luci-app-h5000m-fancontrol
git clone --depth 1 https://github.com/FAN789/luci-app-h5000m-fancontrol.git package/luci-app-h5000m-fancontrol

# 2. Clone MT5700M 5G Module LuCI App
rm -rf package/luci-app-mt5700m
git clone --depth 1 https://github.com/FAN789/luci-app-mt5700m.git package/luci-app-mt5700m

# 3. Clone OpenList & LuCI App (Official OpenListTeam)
echo "Configuring OpenList..."
rm -rf feeds/packages/net/openlist
rm -rf package/feeds/packages/openlist
rm -rf feeds/luci/applications/luci-app-openlist
rm -rf package/feeds/luci/luci-app-openlist
rm -rf package/openlist
git clone --depth 1 https://github.com/OpenListTeam/OpenList-OpenWRT.git package/openlist

# 4. Clone openwrt-daede (dae, daed, luci-app-daede, vmlinux-btf)
echo "Configuring openwrt-daede..."
rm -rf feeds/packages/net/dae
rm -rf feeds/packages/net/daed
rm -rf feeds/luci/applications/luci-app-dae
rm -rf feeds/luci/applications/luci-app-daed
rm -rf package/feeds/packages/dae
rm -rf package/feeds/packages/daed
rm -rf package/feeds/luci/luci-app-dae
rm -rf package/feeds/luci/luci-app-daed
rm -rf package/daede
git clone --depth 1 https://github.com/kenzok8/openwrt-daede.git package/daede

# 5. Apply H5000M DTS patch for userspace fan control
PATCH_FILE=""
if [ -f "${PROJECT_DIR}/patches/h5000m-userspace-fan-control.patch" ]; then
    PATCH_FILE="${PROJECT_DIR}/patches/h5000m-userspace-fan-control.patch"
elif [ -f "../patches/h5000m-userspace-fan-control.patch" ]; then
    PATCH_FILE="../patches/h5000m-userspace-fan-control.patch"
fi

if [ -n "${PATCH_FILE}" ]; then
    echo "Applying DTS patch from ${PATCH_FILE}..."
    patch -p1 < "${PATCH_FILE}" || echo "Warning: Patch already applied or failed"
fi

# 6. Fix MosDNS feed link: prioritize sbwml patched mosdns with adblock_set plugin
echo "Configuring sbwml MosDNS with adblock_set plugin..."
rm -rf package/feeds/packages/mosdns
mkdir -p package/feeds/mosdns
ln -sf ../../../feeds/mosdns/mosdns package/feeds/mosdns/mosdns

if [ -f feeds/packages/net/mosdns/Makefile ]; then
    sed -i '/mosdns-init-openwrt/d' feeds/packages/net/mosdns/Makefile
fi

# 7. Fix unquoted PATH in golang-package.mk to prevent shell syntax errors
if [ -f feeds/packages/lang/golang/golang-package.mk ]; then
    sed -i 's|PATH=\$(STAGING_DIR_HOSTPKG)/lib/go-\$(GO_HOST_VERSION)/bin:\$(PATH)|PATH="\$(STAGING_DIR_HOSTPKG)/lib/go-\$(GO_HOST_VERSION)/bin:\$(PATH)"|' feeds/packages/lang/golang/golang-package.mk
fi

# 8. Enable parallel compilation for llvm-bpf host tool
if [ -f tools/llvm-bpf/Makefile ]; then
    grep -q 'HOST_BUILD_PARALLEL:=1' tools/llvm-bpf/Makefile || sed -i '1i HOST_BUILD_PARALLEL:=1' tools/llvm-bpf/Makefile
fi

echo "DIY Part 2 setup completed successfully."
