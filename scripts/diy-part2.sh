#!/bin/bash
# =================================================================
# DIY script part 2 (After feeds install)
# Description: Clone plugins, apply patches, integrate honk
# =================================================================

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

# 2.2 Add first-boot cleanup script for seamless sysupgrade (removes legacy menu/configs)
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-cleanup-legacy
#!/bin/sh
rm -f /tmp/luci-indexcache
rm -f /etc/config/mt5700m
rm -f /etc/config/qmodem_generic
rm -f /etc/config/momo
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

# 4. Integrate honk (eBPF transparent proxy) and its LuCI app
echo "Integrating honk, luci-app-honk, and luci-lib-daeuniverse..."
rm -rf package/honk package/luci-app-honk package/luci-lib-daeuniverse
git clone --depth 1 https://github.com/daeuniverse/openwrt-packages.git /tmp/daeuniverse-packages

cp -r /tmp/daeuniverse-packages/luci-app-honk package/luci-app-honk
cp -r /tmp/daeuniverse-packages/luci-lib-daeuniverse package/luci-lib-daeuniverse
mkdir -p package/honk/files
cp -r /tmp/daeuniverse-packages/honk/files/* package/honk/files/
rm -rf /tmp/daeuniverse-packages

# Download official prebuilt honk-core (musl full with embedded doona WebUI)
HONK_LATEST_TAG=$(curl -s https://api.github.com/repos/daeuniverse/honk/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
[ -z "$HONK_LATEST_TAG" ] && HONK_LATEST_TAG="v0.1.0-beta.4"
echo "Fetching prebuilt honk-core (${HONK_LATEST_TAG}) for aarch64 musl..."
mkdir -p /tmp/honk-bin
curl -s -L "https://github.com/daeuniverse/honk/releases/download/${HONK_LATEST_TAG}/honk-core-${HONK_LATEST_TAG}-aarch64-unknown-linux-musl-full.tar.gz" -o /tmp/honk-bin/honk-core.tar.gz
tar -xzf /tmp/honk-bin/honk-core.tar.gz -C /tmp/honk-bin/
HONK_BIN_DIR=$(find /tmp/honk-bin -type d -name "honk-core*" | head -n 1)
cp "${HONK_BIN_DIR}/honk-core" package/honk/files/honk-core
chmod +x package/honk/files/honk-core package/honk/files/honk.init
rm -rf /tmp/honk-bin

# Write standalone package/honk/Makefile for prebuilt binary installation
cat << 'EOF' > package/honk/Makefile
include $(TOPDIR)/rules.mk

PKG_NAME:=honk
PKG_VERSION:=0.1.0_beta4
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/honk
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Web Servers/Proxies
  TITLE:=eBPF transparent proxy engine (honk-core) with embedded UI
  URL:=https://github.com/daeuniverse/honk
  DEPENDS:=+libstdcpp +kmod-veth +kmod-sched-core +kmod-sched-bpf \
           +kmod-nft-core +kmod-nft-queue +kmod-nfnetlink-queue \
           +kmod-nf-conntrack +v2ray-geoip +v2ray-geosite
endef

define Package/honk/description
 honk is an eBPF transparent proxy engine with embedded Doona WebUI and LuCI integration.
endef

define Build/Compile
endef

define Package/honk/conffiles
/etc/config/honk
/etc/honk/config.dae
endef

define Package/honk/postinst
#!/bin/sh
[ -z "$${IPKG_INSTROOT}" ] || exit 0
/etc/init.d/honk enabled && /etc/init.d/honk restart
exit 0
endef

define Package/honk/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/honk-core $(1)/usr/bin/honk-core
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/honk.init $(1)/etc/init.d/honk
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/honk.config $(1)/etc/config/honk
	$(INSTALL_DIR) $(1)/etc/honk
	$(INSTALL_CONF) ./files/config.dae $(1)/etc/honk/config.dae
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	printf '%s\n' '/etc/honk/data/' > $(1)/lib/upgrade/keep.d/honk
	$(INSTALL_DIR) $(1)/usr/share/honk
	$(LN) ../v2ray/geoip.dat $(1)/usr/share/honk/geoip.dat
	$(LN) ../v2ray/geosite.dat $(1)/usr/share/honk/geosite.dat
endef

$(eval $(call BuildPackage,honk))
EOF

# Pre-configure daeuniverse APK repository for seamless online updates
mkdir -p files/etc/apk/repositories.d files/etc/apk/keys
curl -s -L "https://openwrt.daeuniverse.org/public-key.pem" -o files/etc/apk/keys/daeuniverse.pem
cat << 'EOF' > files/etc/apk/repositories.d/daeuniverse.list
@daeuniverse https://openwrt.daeuniverse.org/25.12/packages/aarch64_cortex-a53/packages.adb
EOF

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

# 6. Fix unquoted PATH in golang-package.mk to prevent shell syntax errors
if [ -f feeds/packages/lang/golang/golang-package.mk ]; then
    sed -i 's|PATH=\$(STAGING_DIR_HOSTPKG)/lib/go-\$(GO_HOST_VERSION)/bin:\$(PATH)|PATH="\$(STAGING_DIR_HOSTPKG)/lib/go-\$(GO_HOST_VERSION)/bin:\$(PATH)"|' feeds/packages/lang/golang/golang-package.mk
fi

# 7. Clean up removed plugins (momo, sing-box, daede, mt5700m) to prevent leftover builds
rm -rf package/momo package/luci-app-momo feeds/momo package/feeds/momo
rm -rf package/daede package/luci-app-mt5700m feeds/luci/applications/luci-app-mt5700m package/feeds/luci/luci-app-mt5700m
rm -rf feeds/packages/net/dae feeds/packages/net/daed feeds/luci/applications/luci-app-dae feeds/luci/applications/luci-app-daed
rm -rf package/feeds/packages/dae package/feeds/packages/daed package/feeds/luci/luci-app-dae package/feeds/luci/luci-app-daed
rm -rf feeds/packages/net/mosdns feeds/luci/applications/luci-app-mosdns package/feeds/packages/mosdns package/feeds/luci/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-passwall package/feeds/luci/luci-app-passwall

echo "DIY Part 2 setup completed successfully."
