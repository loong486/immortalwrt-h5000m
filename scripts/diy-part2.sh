#!/bin/bash
# =================================================================
# DIY script part 2 (After feeds install)
# Description: Clone plugins, apply patches, fix feeds precedence
# =================================================================

# ── User-configurable version ───────────────────────────────────
# Change this single variable to upgrade sing-box in future builds
SING_BOX_VERSION="1.14.4"
# ────────────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Clone Hiveton H5000M Fan Control LuCI App
rm -rf package/luci-app-h5000m-fancontrol
git clone --depth 1 https://github.com/FAN789/luci-app-h5000m-fancontrol.git package/luci-app-h5000m-fancontrol

# 2. Clean up legacy packages
rm -rf package/luci-app-mt5700m package/luci-app-qmodem-generic

# 2.1 Clean up QModem version string if needed (apk compatibility)
if [ -f feeds/qmodem/version.mk ]; then
    sed -i -E 's/^(QMODEM_VERSION:=[0-9]+\.[0-9]+\.[0-9]+)-rc\.([0-9]+)$/\1_rc\2/' feeds/qmodem/version.mk
fi

# 2.1.1 Fix ndisc6 upstream download URL and pre-populate dl cache
echo "Fixing ndisc6 source URL and cache..."
for f in feeds/qmodem/application/ndisc6/Makefile package/feeds/qmodem/ndisc6/Makefile; do
    if [ -f "$f" ]; then
        sed -i 's|http://www.remlab.net/files/ndisc6|https://www.remlab.net/files/ndisc6/archive/|g' "$f"
    fi
done

mkdir -p dl
if [ -f "${PROJECT_DIR}/patches/sources/ndisc6-1.0.2.tar.bz2" ]; then
    echo "Copying bundled ndisc6-1.0.2.tar.bz2 to dl/..."
    cp "${PROJECT_DIR}/patches/sources/ndisc6-1.0.2.tar.bz2" dl/ndisc6-1.0.2.tar.bz2
elif [ ! -s dl/ndisc6-1.0.2.tar.bz2 ]; then
    echo "Pre-fetching ndisc6-1.0.2.tar.bz2..."
    curl -f -s -L --retry 3 "https://www.remlab.net/files/ndisc6/archive/ndisc6-1.0.2.tar.bz2" -o dl/ndisc6-1.0.2.tar.bz2 || true
fi

# 2.2 Add first-boot cleanup script for seamless sysupgrade (removes legacy menu/configs)
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-cleanup-legacy
#!/bin/sh
rm -rf /tmp/luci-modulecache /tmp/luci-indexcache*
rm -f /etc/config/mt5700m
rm -f /etc/config/qmodem_generic
rm -f /etc/config/honk
rm -rf /etc/honk /usr/lib/debug/boot/vmlinux
rm -f /etc/apk/repositories.d/daeuniverse.list /etc/apk/keys/daeuniverse.pem
# Remove nonexistent upstream feeds (qmodem, video, momo, daeuniverse) to prevent apk update errors
sed -i '/qmodem/d;/video/d;/momo/d;/daeuniverse/d' /etc/apk/repositories.d/*.list /etc/apk/repositories 2>/dev/null
exit 0
EOF
chmod +x files/etc/uci-defaults/99-cleanup-legacy

# 2.3 Fix python-pyserial build dependency (backport upstream fix e2ffecaab6)
if [ -f feeds/packages/lang/python/python-pyserial/Makefile ]; then
    sed -i 's/HOST_BUILD_DEPENDS:=.*/HOST_BUILD_DEPENDS:=python-setuptools\/host\nPKG_BUILD_DEPENDS:=python-setuptools\/host/' feeds/packages/lang/python/python-pyserial/Makefile
fi

# 2.4 Clone MT5700 WebUI & AT Server (inotdream/mt5700webui-openwrt-server)
rm -rf package/at-webserver package/luci-app-at-webserver
git clone --depth 1 https://github.com/inotdream/mt5700webui-openwrt-server.git /tmp/mt5700webui-repo
cp -r /tmp/mt5700webui-repo/at-webserver package/at-webserver
cp -r /tmp/mt5700webui-repo/luci-app-at-webserver package/luci-app-at-webserver
rm -rf /tmp/mt5700webui-repo

# Replace nonexistent python3-aiohttp dependency with standard python3-urllib
sed -i 's/+python3-aiohttp/+python3-urllib/g' package/at-webserver/Makefile
if [ -f "${PROJECT_DIR}/scripts/patch_at_server.py" ]; then
    python3 "${PROJECT_DIR}/scripts/patch_at_server.py" package/at-webserver/files/usr/bin/at-server.py || true
elif [ -f "scripts/patch_at_server.py" ]; then
    python3 scripts/patch_at_server.py package/at-webserver/files/usr/bin/at-server.py || true
fi

chmod +x package/at-webserver/files/usr/bin/* package/at-webserver/files/etc/init.d/* package/at-webserver/files/www/cgi-bin/* 2>/dev/null || true

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

# 7. Clean up removed plugins (honk, daede, mosdns, passwall, mt5700m) to prevent leftover builds
rm -rf package/honk package/luci-app-honk package/luci-lib-daeuniverse
rm -rf package/daede
rm -rf package/luci-app-mt5700m feeds/luci/applications/luci-app-mt5700m package/feeds/luci/luci-app-mt5700m
rm -rf feeds/packages/net/dae feeds/packages/net/daed feeds/luci/applications/luci-app-dae feeds/luci/applications/luci-app-daed
rm -rf package/feeds/packages/dae package/feeds/packages/daed package/feeds/luci/luci-app-dae package/feeds/luci/luci-app-daed
rm -rf feeds/packages/net/mosdns feeds/luci/applications/luci-app-mosdns package/feeds/packages/mosdns package/feeds/luci/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-passwall package/feeds/luci/luci-app-passwall

echo "DIY Part 2 setup completed successfully."
