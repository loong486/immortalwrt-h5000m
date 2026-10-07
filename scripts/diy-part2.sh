#!/bin/bash
# =================================================================
# DIY script part 2 (After feeds install)
# Description: Clone plugins, apply patches, fix feeds precedence
# =================================================================

# ── User-configurable version ───────────────────────────────────
# Change this single variable to upgrade sing-box in future builds
SING_BOX_VERSION="1.14.2"
# ────────────────────────────────────────────────────────────────

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

# 4. Apply H5000M DTS patch for userspace fan control
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

# 5. Fix unquoted PATH in golang-package.mk to prevent shell syntax errors
if [ -f feeds/packages/lang/golang/golang-package.mk ]; then
    sed -i 's|PATH=\$(STAGING_DIR_HOSTPKG)/lib/go-\$(GO_HOST_VERSION)/bin:\$(PATH)|PATH="\$(STAGING_DIR_HOSTPKG)/lib/go-\$(GO_HOST_VERSION)/bin:\$(PATH)"|' feeds/packages/lang/golang/golang-package.mk
fi

# 6. Override sing-box version to ${SING_BOX_VERSION} (upstream feed ships older 1.12.x)
SING_BOX_MK="feeds/packages/net/sing-box/Makefile"
if [ -f "${SING_BOX_MK}" ]; then
    echo "Upgrading sing-box to v${SING_BOX_VERSION}..."
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${SING_BOX_VERSION}/" "${SING_BOX_MK}"
    sed -i "s/^PKG_HASH:=.*/PKG_HASH:=skip/" "${SING_BOX_MK}"
    sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=1/" "${SING_BOX_MK}"
else
    echo "Warning: sing-box Makefile not found at ${SING_BOX_MK}"
fi

# 7. Clean up removed plugins (daede, mosdns, passwall) to prevent leftover builds
rm -rf package/daede
rm -rf feeds/packages/net/dae feeds/packages/net/daed feeds/luci/applications/luci-app-dae feeds/luci/applications/luci-app-daed
rm -rf package/feeds/packages/dae package/feeds/packages/daed package/feeds/luci/luci-app-dae package/feeds/luci/luci-app-daed
rm -rf feeds/packages/net/mosdns feeds/luci/applications/luci-app-mosdns package/feeds/packages/mosdns package/feeds/luci/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-passwall package/feeds/luci/luci-app-passwall

echo "DIY Part 2 setup completed successfully."
