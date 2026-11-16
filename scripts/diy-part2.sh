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

if ! command python3 -c "import sys" >/dev/null 2>&1; then
    python3() { command python "$@"; }
fi

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

# 2.2 Add first-boot cleanup script for seamless sysupgrade (removes legacy menu/configs + H5000M defaults)
mkdir -p files/etc/uci-defaults
cat << 'EOF' > files/etc/uci-defaults/99-cleanup-legacy
#!/bin/sh
rm -rf /tmp/luci-modulecache /tmp/luci-indexcache*
if [ -x /etc/init.d/at-webserver ]; then
    /etc/init.d/at-webserver stop >/dev/null 2>&1 || true
    /etc/init.d/at-webserver disable >/dev/null 2>&1 || true
fi
rm -f /etc/init.d/at-webserver /etc/rc.d/*at-webserver* /etc/config/at-webserver /usr/bin/at-server.py
rm -rf /www/5700
rm -f /etc/config/mt5700m /etc/config/qmodem_generic /etc/config/honk
rm -rf /etc/honk /usr/lib/debug/boot/vmlinux
rm -f /etc/apk/repositories.d/daeuniverse.list /etc/apk/keys/daeuniverse.pem
sed -i '/qmodem/d;/video/d;/momo/d;/daeuniverse/d' /etc/apk/repositories.d/*.list /etc/apk/repositories 2>/dev/null

# 1. Default LAN IP = 192.168.88.1
uci -q set network.lan.ipaddr='192.168.88.1'
uci -q set network.lan.netmask='255.255.255.0'
uci -q commit network

# 2. Default root password = root
printf "root\nroot\n" | passwd root >/dev/null 2>&1 || true

# 3. Unified Wi-Fi password = 198198ko across all existing wifi-iface sections
for s in $(uci -q show wireless | sed -n "s/^wireless\.\([^.=]*\)=wifi-iface$/\1/p"); do
    dev=$(uci -q get "wireless.${s}.device")
    band=$(uci -q get "wireless.${dev}.band")
    enc=$(uci -q get "wireless.${s}.encryption")
    if [ -z "$enc" ] || [ "$enc" = "none" ] || [ "$enc" = "owe" ]; then
        if [ "$band" = "6g" ]; then
            uci -q set "wireless.${s}.encryption=sae"
        else
            uci -q set "wireless.${s}.encryption=psk2"
        fi
    fi
    uci -q set "wireless.${s}.key=198198ko"
    uci -q set "wireless.${s}.disabled=0"
done
uci -q commit wireless

# 4. Disable hardware/software flow offloading by default (prevents MT5700M USB CDC NAT desync)
uci -q set firewall.@defaults[0].flow_offloading='0'
uci -q set firewall.@defaults[0].flow_offloading_hw='0'
uci -q commit firewall

# 5. H5000M QModem USB slot preset & preserve SIM SMS for ModemWebUI + smsforward
if [ -f /etc/config/qmodem ]; then
    uci -q set qmodem.usb0='modem-slot'
    uci -q set qmodem.usb0.slot='2-1'
    uci -q set qmodem.usb0.type='usb'
    uci -q set qmodem.usb0.alias='USB'
    uci -q set qmodem.main.enable_pcie_scan='0'
    uci -q set qmodem.main.start_delay='9'
    for m in $(uci -q show qmodem | sed -n "s/^qmodem\.\([^.=]*\)=modem-device$/\1/p"); do
        uci -q set "qmodem.${m}.sms_auto_delete_from_sim=0"
    done
    uci -q commit qmodem
fi
if [ -f /etc/config/sms_forwarder ]; then
    uci -q set sms_forwarder.sms_forward.enable='0'
    uci -q commit sms_forwarder
fi
exit 0
EOF
chmod +x files/etc/uci-defaults/99-cleanup-legacy

# 2.3 Clone & patch MT5700/Modem WebUI (lonelysix-editor/luci-app-modemwebui)
rm -rf package/luci-app-modemwebui package/at-webserver package/luci-app-at-webserver /tmp/modemwebui-repo
git clone --depth 1 https://github.com/lonelysix-editor/luci-app-modemwebui.git /tmp/modemwebui-repo || exit 1
cp -r /tmp/modemwebui-repo/luci-app-modemwebui package/luci-app-modemwebui || exit 1
rm -rf /tmp/modemwebui-repo

# Normalize LF only on text files (never touch binary usr/bin/webuiserver or .lmo/.png)
find package/luci-app-modemwebui -type f \( -name 'Makefile' -o -path '*/etc/init.d/*' -o -path '*/etc/hotplug.d/*' -o -name '*.lua' -o -name '*.htm' -o -name '*.json' -o -name '*.bak' \) -exec sed -i 's/\r$//' {} +

python3 - << 'EOPY' || exit 1
import json

# 1. Patch package/luci-app-modemwebui/Makefile
mk_path = "package/luci-app-modemwebui/Makefile"
with open(mk_path, "r", encoding="utf-8", newline="") as f:
    mk = f.read()
old_dep = "DEPENDS:=@aarch64 +luci-base +qmodem +usbutils +libgcc"
new_dep = "DEPENDS:=@aarch64 +luci-base +luci-compat +luci-lua-runtime +qmodem +usbutils +libgcc +coreutils-sha1sum"
assert old_dep in mk, f"Missing target DEPENDS in {mk_path}"
mk = mk.replace(old_dep, new_dep, 1)

install_anchor = "\t$(INSTALL_BIN) $(PKG_BUILD_DIR)/etc/init.d/modemwebui $(1)/etc/init.d/modemwebui\n"
install_extra = (
    "\n\t$(INSTALL_DIR) $(1)/etc/hotplug.d/iface\n"
    "\t$(INSTALL_BIN) $(PKG_BUILD_DIR)/etc/hotplug.d/iface/99-modemwebui $(1)/etc/hotplug.d/iface/99-modemwebui\n"
)
assert install_anchor in mk, f"Missing install anchor in {mk_path}"
mk = mk.replace(install_anchor, install_anchor + install_extra, 1)
with open(mk_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(mk)

# 2. Patch package/luci-app-modemwebui/etc/init.d/modemwebui
init_path = "package/luci-app-modemwebui/etc/init.d/modemwebui"
with open(init_path, "r", encoding="utf-8", newline="") as f:
    init_txt = f.read()
old_lan = "DEFAULT_LAN_ADDR=192.168.1.1"
new_lan = "DEFAULT_LAN_ADDR=192.168.88.1"
assert old_lan in init_txt, f"Missing {old_lan} in {init_path}"
assert 'sed "s/192\\.168\\.1\\.1/$lan_addr/g" "${config_file}.bak"' in init_txt, f"Missing sed template in {init_path}"
init_txt = init_txt.replace(old_lan, new_lan, 1)
with open(init_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(init_txt)

# 3. Patch both webui5700/config.json and webui000/config.json to tom_modem mode
for cfg_path in (
    "package/luci-app-modemwebui/www/webui/webui5700/config.json",
    "package/luci-app-modemwebui/www/webui/webui000/config.json",
):
    with open(cfg_path, "r", encoding="utf-8", newline="") as f:
        data = json.load(f)
    assert "SERIAL" in data and "MODE" in data["SERIAL"], f"Missing SERIAL.MODE in {cfg_path}"
    data["SERIAL"]["MODE"] = "tom_modem"
    with open(cfg_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, indent=2) + "\n")
EOPY

chmod +x package/luci-app-modemwebui/etc/init.d/modemwebui package/luci-app-modemwebui/etc/hotplug.d/iface/99-modemwebui package/luci-app-modemwebui/usr/bin/webuiserver

# 2.4 Clone & patch SMS Forward (snowflakexuehui/luci-app-smsforward)
rm -rf package/smsforward package/luci-app-smsforward /tmp/smsforward-repo
git clone --depth 1 https://github.com/snowflakexuehui/luci-app-smsforward.git /tmp/smsforward-repo || exit 1
cp -r /tmp/smsforward-repo/smsforward package/smsforward || exit 1
cp -r /tmp/smsforward-repo/luci-app-smsforward package/luci-app-smsforward || exit 1
rm -rf /tmp/smsforward-repo

# Strip CRLF (\r) on all text files in package/smsforward and package/luci-app-smsforward (exclude *.png)
find package/smsforward package/luci-app-smsforward -type f ! -name '*.png' -exec sed -i 's/\r$//' {} +

python3 - << 'EOPY' || exit 1
def patch_file(path, old, new):
    with open(path, "r", encoding="utf-8", newline="") as f:
        text = f.read().replace("\r\n", "\n")
    assert old in text, f"Missing target string {old!r} in {path}"
    text = text.replace(old, new, 1)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

patch_file(
    "package/luci-app-smsforward/Makefile",
    "LUCI_DEPENDS:=+luci +smsforward",
    "LUCI_DEPENDS:=+luci-base +luci-compat +luci-lua-runtime +smsforward",
)
patch_file(
    "package/smsforward/Makefile",
    "  DEPENDS:=\n",
    "  DEPENDS:=+curl +ca-bundle\n",
)
patch_file(
    "package/smsforward/smsforward.c",
    '"tom_modem -c \'%s\' -d \'%s\' -b %d 2>/dev/null"',
    '"tom_modem -u -c \'%s\' -d \'%s\' -b %d 2>/dev/null"',
)
EOPY

chmod +x package/luci-app-smsforward/root/etc/init.d/smsforward

# 2.5 Patch QModem (feeds/qmodem) for zero-conflict ubus sharing & non-destructive SIM SMS
python3 - << 'EOPY' || exit 1
import os

# 1. tom_modem: auto-detect active ubus at-daemon even if -u was omitted
tom_main = "feeds/qmodem/application/tom_modem/src/main.c"
with open(tom_main, "r", encoding="utf-8", newline="") as f:
    text = f.read()

target = (
    "    // Default transport is TTY\n"
    "    if (profile->transport != TRANSPORT_UBUS)\n"
    "    {\n"
    "        profile->transport = TRANSPORT_TTY;\n"
    "    }"
)
replacement = (
    "    // Default transport: prefer UBUS when at-daemon is active, fallback to TTY\n"
    "    if (profile->transport != TRANSPORT_UBUS)\n"
    "    {\n"
    "#ifdef ENABLE_UBUS_DAEMON\n"
    "        struct ubus_context *probe_ctx = ubus_connect(NULL);\n"
    "        uint32_t svc_id = 0;\n"
    "        if (probe_ctx && ubus_lookup_id(probe_ctx, UBUS_AT_DAEMON_SERVICE, &svc_id) == UBUS_STATUS_OK)\n"
    "        {\n"
    "            profile->transport = TRANSPORT_UBUS;\n"
    "        }\n"
    "        else\n"
    "        {\n"
    "            profile->transport = TRANSPORT_TTY;\n"
    "        }\n"
    "        if (probe_ctx)\n"
    "        {\n"
    "            ubus_free(probe_ctx);\n"
    "        }\n"
    "#else\n"
    "        profile->transport = TRANSPORT_TTY;\n"
    "#endif\n"
    "    }"
)
assert target in text, f"Target block not found in {tom_main}"
text = text.replace(target, replacement, 1)
with open(tom_main, "w", encoding="utf-8", newline="\n") as f:
    f.write(text)

# 2. qmodem_smsd: default sms_auto_delete_from_sim to 0 (non-destructive)
smsd_main = "feeds/qmodem/application/qmodem_smsd/src/main.c"
with open(smsd_main, "r", encoding="utf-8", newline="") as f:
    smsd_text = f.read()
old_smsd = '"sms_auto_delete_from_sim", "1"'
new_smsd = '"sms_auto_delete_from_sim", "0"'
assert old_smsd in smsd_text, f"Target string not found in {smsd_main}"
smsd_text = smsd_text.replace(old_smsd, new_smsd, 1)
with open(smsd_main, "w", encoding="utf-8", newline="\n") as f:
    f.write(smsd_text)

# 3. Optional ucode qmodem_sms fallback if present
ucode_sms = "feeds/qmodem/application/qmodem/files/usr/share/rpcd/ucode/qmodem_sms"
if os.path.exists(ucode_sms):
    with open(ucode_sms, "r", encoding="utf-8", newline="") as f:
        uc_text = f.read()
    old_uc = "cfg.sms_auto_delete_from_sim != '0'"
    new_uc = "cfg.sms_auto_delete_from_sim == '1'"
    assert old_uc in uc_text, f"Target string not found in {ucode_sms}"
    uc_text = uc_text.replace(old_uc, new_uc, 1)
    with open(ucode_sms, "w", encoding="utf-8", newline="\n") as f:
        f.write(uc_text)
EOPY

# 2.6 Build-time Base System Defaults (LAN IP 192.168.88.1, root password root, Wi-Fi password 198198ko)
sed -i 's/192\.168\.1\.1/192.168.88.1/g' package/base-files/files/bin/config_generate || exit 1
grep -q '192\.168\.88\.1' package/base-files/files/bin/config_generate || exit 1

python3 - << 'EOPY' || exit 1
import subprocess

# 1. Default root password = root
shadow_path = "package/base-files/files/etc/shadow"
hashed = subprocess.check_output(["openssl", "passwd", "-1", "root"], text=True).strip()
assert hashed.startswith("$1$"), f"Unexpected openssl hash: {hashed!r}"
with open(shadow_path, "r", encoding="utf-8", newline="") as f:
    lines = f.read().splitlines(keepends=True)
replaced_shadow = False
new_lines = []
for line in lines:
    if line.startswith("root:"):
        new_lines.append(f"root:{hashed}:19999:0:99999:7:::\n")
        replaced_shadow = True
    else:
        new_lines.append(line)
assert replaced_shadow, f"root: line not found in {shadow_path}"
with open(shadow_path, "w", encoding="utf-8", newline="\n") as f:
    f.writelines(new_lines)

# 2. Unified Wi-Fi defaults (psk2 / sae on 6g, key = 198198ko)
mac80211_path = "package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
with open(mac80211_path, "r", encoding="utf-8", newline="") as f:
    mac_text = f.read()

replacements = [
    ("encryption = 'owe';", "encryption = 'sae';"),
    ("encryption = 'none';", "encryption = 'psk2';"),
    (
        "set ${si}.encryption='${defaults?.encryption || encryption}'",
        "set ${si}.encryption='${band_name == \"6g\" ? \"sae\" : \"psk2\"}'",
    ),
    (
        "set ${si}.key='${defaults?.key || \"\"}'",
        "set ${si}.key='198198ko'",
    ),
]
for old, new in replacements:
    assert old in mac_text, f"Missing target {old!r} in {mac80211_path}"
    mac_text = mac_text.replace(old, new, 1)

with open(mac80211_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(mac_text)
EOPY

# 3. Clone OpenList & LuCI App (Official OpenListTeam)
echo "Configuring OpenList..."
rm -rf feeds/packages/net/openlist
rm -rf package/feeds/packages/openlist
rm -rf feeds/luci/applications/luci-app-openlist
rm -rf package/feeds/luci/luci-app-openlist
rm -rf package/openlist
git clone --depth 1 https://github.com/OpenListTeam/OpenList-OpenWRT.git package/openlist

# 3.5 Pre-install official prebuilt llvm-bpf toolchain (avoids 70-min LLVM source build & runner OOM)
if [ -f tools/llvm-bpf/Makefile ]; then
    LLVM_BPF_VER=$(sed -n 's/^PKG_VERSION:=//p' tools/llvm-bpf/Makefile | head -n1 | tr -d '[:space:]')
    LLVM_BPF_TAR="llvm-bpf-${LLVM_BPF_VER}.Linux-x86_64.tar.zst"
    echo "Fetching prebuilt ${LLVM_BPF_TAR}..."
    if curl -f -s -L --retry 3 "https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/targets/mediatek/filogic/${LLVM_BPF_TAR}" -o "/tmp/${LLVM_BPF_TAR}" || \
       curl -f -s -L --retry 3 "https://mirrors.vsean.net/openwrt/releases/25.12-SNAPSHOT/targets/mediatek/filogic/${LLVM_BPF_TAR}" -o "/tmp/${LLVM_BPF_TAR}" || \
       curl -f -s -L --retry 3 "https://downloads.openwrt.org/releases/25.12-SNAPSHOT/targets/mediatek/filogic/${LLVM_BPF_TAR}" -o "/tmp/${LLVM_BPF_TAR}"; then
        tar -I zstd -xf "/tmp/${LLVM_BPF_TAR}" -C .
        rm -f "/tmp/${LLVM_BPF_TAR}"
        ls -la llvm-bpf/.llvm-version
    else
        echo "Warning: Prebuilt ${LLVM_BPF_TAR} unavailable, falling back to host LLVM toolchain..."
        cat << 'EOCFG' >> .config
CONFIG_DEVEL=y
CONFIG_BPF_TOOLCHAIN_HOST=y
# CONFIG_BPF_TOOLCHAIN_BUILD_LLVM is not set
EOCFG
    fi
fi

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
    echo "Upgrading sing-box to v${SING_BOX_VERSION} (with Go 1.26 linkname compatibility)..."
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=${SING_BOX_VERSION}/" "${SING_BOX_MK}"
    sed -i "s/^PKG_HASH:=.*/PKG_HASH:=skip/" "${SING_BOX_MK}"
    sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=1/" "${SING_BOX_MK}"
    grep -q '^GO_PKG_LDFLAGS:=' "${SING_BOX_MK}" || sed -i '/^GO_PKG_LDFLAGS_X:=/i GO_PKG_LDFLAGS:=-checklinkname=0' "${SING_BOX_MK}"
    sed -i 's|^GO_PKG_LDFLAGS_X:=.*|GO_PKG_LDFLAGS_X:=$(GO_PKG)/constant.Version=$(PKG_VERSION) runtime.godebugDefault=multipathtcp=0,tlssha1=1|' "${SING_BOX_MK}"
    if ! grep -q 'badlinkname' "${SING_BOX_MK}"; then
        sed -i 's/GO_PKG_TAGS:=with_acme,/GO_PKG_TAGS:=badlinkname,tfogo_checklinkname0,with_acme,/' "${SING_BOX_MK}"
        sed -i 's/GO_PKG_TAGS:=\$(subst \$(space),\$(comma),\$(strip \\/GO_PKG_TAGS:=\$(subst \$(space),\$(comma),\$(strip badlinkname tfogo_checklinkname0 \\/' "${SING_BOX_MK}"
    fi
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
