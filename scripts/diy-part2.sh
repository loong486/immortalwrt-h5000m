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
for svc in at-webserver momo openlist frpc; do
    if [ -x "/etc/init.d/${svc}" ]; then
        "/etc/init.d/${svc}" stop >/dev/null 2>&1 || true
        "/etc/init.d/${svc}" disable >/dev/null 2>&1 || true
    fi
done
rm -f /etc/init.d/at-webserver /etc/rc.d/*at-webserver* /etc/config/at-webserver /usr/bin/at-server.py
rm -f /etc/init.d/momo /etc/rc.d/*momo* /etc/config/momo
rm -f /etc/init.d/openlist /etc/rc.d/*openlist* /etc/config/openlist
rm -f /etc/init.d/frpc /etc/rc.d/*frpc* /etc/config/frpc
rm -rf /www/5700 /etc/momo /var/log/momo /var/run/momo /etc/openlist /var/run/openlist
if uci -q get firewall.momo >/dev/null 2>&1; then
    uci -q delete firewall.momo
    uci -q commit firewall
fi
rm -f /etc/config/mt5700m /etc/config/qmodem_generic /etc/config/honk
rm -rf /etc/honk /usr/lib/debug/boot/vmlinux
rm -f /etc/apk/repositories.d/daeuniverse.list /etc/apk/keys/daeuniverse.pem
sed -i '/qmodem/d;/video/d;/momo/d;/mosdns/d;/daeuniverse/d' /etc/apk/repositories.d/*.list /etc/apk/repositories 2>/dev/null

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
import glob
import json
import os

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

www_install_anchor = "\t$(CP) $(PKG_BUILD_DIR)/www/. $(1)/www/\n"
assert www_install_anchor in mk, f"Missing www install rule in {mk_path}"

postinst_anchor = '\tln -sf ../init.d/modemwebui "$${IPKG_INSTROOT}/etc/rc.d/S99modemwebui"\n'
postinst_extra = '\tln -sf ../init.d/modemwebui "$${IPKG_INSTROOT}/etc/rc.d/K10modemwebui"\n'
assert postinst_anchor in mk, f"Missing postinst symlink anchor in {mk_path}"
mk = mk.replace(postinst_anchor, postinst_anchor + postinst_extra, 1)

with open(mk_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(mk)

# 2. Patch package/luci-app-modemwebui/etc/init.d/modemwebui
init_path = "package/luci-app-modemwebui/etc/init.d/modemwebui"
with open(init_path, "r", encoding="utf-8", newline="") as f:
    init_txt = f.read()
old_lan = "DEFAULT_LAN_ADDR=192.168.1.1"
new_lan = """DEFAULT_LAN_ADDR=192.168.88.1
AT_PORT_FILE=/var/run/modemwebui.at_port

get_qmodem_at_port() {
    local at_port fallback sec

    at_port=$(uci -q get qmodem.@modem-device[0].at_port 2>/dev/null)
    if [ -n "$at_port" ] && [ -e "$at_port" ]; then
        echo "$at_port"
        return 0
    fi
    fallback="$at_port"

    for sec in $(uci -q show qmodem 2>/dev/null | sed -n "s/^qmodem\\.\\([^.=]*\\)=modem-device$/\\1/p"); do
        at_port=$(uci -q get "qmodem.${sec}.at_port" 2>/dev/null)
        if [ -n "$at_port" ] && [ -e "$at_port" ]; then
            echo "$at_port"
            return 0
        fi
        [ -z "$fallback" ] && [ -n "$at_port" ] && fallback="$at_port"
    done

    [ -n "$fallback" ] && echo "$fallback"
}"""
assert old_lan in init_txt, f"Missing {old_lan} in {init_path}"
assert 'sed "s/192\\.168\\.1\\.1/$lan_addr/g" "${config_file}.bak"' in init_txt, f"Missing sed template in {init_path}"
init_txt = init_txt.replace(old_lan, new_lan, 1)

old_start_instance = (
    "start_service_instance() {\n"
    "    local CONFIG_FILE=$1\n"
    "    \n"
    "    sleep 6\n"
    '    write_web_config "$CONFIG_FILE"\n'
    "    \n"
    "    # 使用procd启动服务，支持自动重启\n"
    "    # 通过sh -c在webuiserver所在目录执行，使用相对路径启动\n"
    "    procd_open_instance\n"
    '    procd_set_param command /bin/sh -c "cd \'$(dirname "$CONFIG_FILE")/../\' && exec \'/usr/bin/webuiserver\'"\n'
    "    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-0}\n"
    "    procd_set_param stdout 1\n"
    "    procd_set_param stderr 1\n"
    "    procd_close_instance\n"
    "    \n"
    "    sleep 1\n"
    "    rm -rf /tmp/luci-*\n"
    "}"
)
new_start_instance = """start_service_instance() {
    local CONFIG_FILE=$1
    local at_port wait_sec=0

    at_port=$(get_qmodem_at_port)
    while [ "$wait_sec" -lt 15 ]; do
        if [ -n "$at_port" ] && [ -e "$at_port" ]; then
            break
        fi
        sleep 1
        wait_sec=$((wait_sec + 1))
        at_port=$(get_qmodem_at_port)
    done

    if [ -n "$at_port" ] && [ -e "$at_port" ]; then
        printf '%s\\n' "$at_port" > "$AT_PORT_FILE"
    else
        rm -f "$AT_PORT_FILE"
    fi

    write_web_config "$CONFIG_FILE"

    # 使用procd启动服务，支持自动重启
    # 通过sh -c在webuiserver所在目录执行，使用相对路径启动
    procd_open_instance
    procd_set_param command /bin/sh -c "cd '$(dirname "$CONFIG_FILE")/../' && exec '/usr/bin/webuiserver'"
    [ -n "$at_port" ] && procd_set_param env AT_PORT="$at_port"
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-0}
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_close_instance
}"""
assert old_start_instance in init_txt, f"Missing start_service_instance block in {init_path}"
init_txt = init_txt.replace(old_start_instance, new_start_instance, 1)

old_triggers_and_hooks = (
    "service_triggers() {\n"
    "    procd_add_reload_trigger network\n"
    "}\n"
    "\n"
    "reload_service() {\n"
    "    write_all_web_configs\n"
    "    rm -rf /tmp/luci-*\n"
    "}\n"
    "\n"
    "stop_service() {\n"
    "    # procd会自动处理停止\n"
    "    return 0\n"
    "} "
)
new_triggers_and_hooks = """service_triggers() {
    procd_add_reload_trigger network qmodem
}

service_started() {
    sleep 1
    rm -rf /tmp/luci-*
}

reload_service() {
    local cur_port prev_port need_restart=0

    write_all_web_configs
    rm -rf /tmp/luci-*

    cur_port=$(get_qmodem_at_port)
    prev_port=""
    [ -f "$AT_PORT_FILE" ] && prev_port=$(cat "$AT_PORT_FILE" 2>/dev/null)

    if [ -n "$cur_port" ] && [ -e "$cur_port" ]; then
        if pidof webuiserver >/dev/null 2>&1; then
            if [ "$cur_port" != "$prev_port" ]; then
                need_restart=1
            elif [ -n "$prev_port" ] && [ ! -e "$prev_port" ]; then
                need_restart=1
            fi
        elif enabled 2>/dev/null || [ -L /etc/rc.d/S99modemwebui ]; then
            need_restart=1
        fi
    fi

    if [ "$need_restart" = "1" ]; then
        restart
    fi
}

stop_service() {
    rm -f "$AT_PORT_FILE"
    return 0
}

service_stopped() {
    local wait_sec=0

    while [ "$wait_sec" -lt 6 ] && pidof webuiserver >/dev/null 2>&1; do
        sleep 1
        wait_sec=$((wait_sec + 1))
    done
}"""
assert old_triggers_and_hooks in init_txt, f"Missing service_triggers/reload_service/stop_service block in {init_path}"
init_txt = init_txt.replace(old_triggers_and_hooks, new_triggers_and_hooks, 1)

with open(init_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(init_txt)

# 3. Patch both webui5700/config.json and webui000/config.json to qmodem + tom_modem mode
for cfg_path in (
    "package/luci-app-modemwebui/www/webui/webui5700/config.json",
    "package/luci-app-modemwebui/www/webui/webui000/config.json",
):
    with open(cfg_path, "r", encoding="utf-8", newline="") as f:
        data = json.load(f)
    assert "SERIAL" in data and "PORT" in data["SERIAL"] and "MODE" in data["SERIAL"], f"Missing SERIAL.PORT/MODE in {cfg_path}"
    data["SERIAL"]["PORT"] = "qmodem"
    data["SERIAL"]["MODE"] = "tom_modem"
    with open(cfg_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, indent=2) + "\n")

# 4. Bump webui5700 AT commandTimeout from 1000ms to 5000ms (AT+CFUN=0/1 during SMS toggle can exceed 1s)
umi_files = sorted(glob.glob("package/luci-app-modemwebui/www/webui/webui5700/web/umi.*.js"))
assert len(umi_files) == 1, f"Expected 1 webui5700 umi.*.js bundle, found: {umi_files}"
umi_path = umi_files[0]
with open(umi_path, "r", encoding="utf-8", newline="") as f:
    umi_txt = f.read()
old_timeout = ',"commandTimeout",1e3)'
new_timeout = ',"commandTimeout",5e3)'
assert umi_txt.count(old_timeout) == 1, f"Expected exact 1 occurrence of {old_timeout!r} in {umi_path}"
umi_txt = umi_txt.replace(old_timeout, new_timeout, 1)
with open(umi_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(umi_txt)

# 5. Patch LuCI controller menu order (10 -> 20 so QModem stays firstchild under admin/modem)
ctrl_path = "package/luci-app-modemwebui/usr/lib/lua/luci/controller/modemwebui.lua"
with open(ctrl_path, "r", encoding="utf-8", newline="") as f:
    ctrl_txt = f.read()
old_entry = 'entry({"admin", "modem", "modemwebui"}, template("modemwebui/modemwebui"), _("ModemWebUI"), 10).leaf = true'
new_entry = 'entry({"admin", "modem", "modemwebui"}, template("modemwebui/modemwebui"), _("ModemWebUI"), 20).leaf = true'
assert old_entry in ctrl_txt, f"Missing target entry in {ctrl_path}"
ctrl_txt = ctrl_txt.replace(old_entry, new_entry, 1)
with open(ctrl_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(ctrl_txt)

# 6. Replace cramped Argon-hardcoded iframe view with clean new-window launcher page
view_path = "package/luci-app-modemwebui/usr/lib/lua/luci/view/modemwebui/modemwebui.htm"
with open(view_path, "r", encoding="utf-8", newline="") as f:
    old_view = f.read()
assert "embedded-iframe" in old_view, f"Unexpected upstream view content in {view_path}"
new_view = """<%+header%>
<div class="cbi-map">
\t<h2><%:ModemWebUI%></h2>
\t<div class="cbi-section">
\t\t<div class="cbi-section-node">
\t\t\t<p id="modemwebui-status" style="margin: 0 0 1em 0;">正在新窗口打开 ModemWebUI…</p>
\t\t\t<p style="margin: 0 0 1.2em 0;">
\t\t\t\t<span>目标地址：</span>
\t\t\t\t<a id="modemwebui-url-link" href="#" target="_blank" rel="noopener noreferrer"></a>
\t\t\t</p>
\t\t\t<div>
\t\t\t\t<a id="modemwebui-open-btn" class="btn cbi-button cbi-button-action" href="#" target="_blank" rel="noopener noreferrer">在新窗口打开 ModemWebUI</a>
\t\t\t</div>
\t\t</div>
\t</div>
</div>
<script>
(function () {
\tvar host = window.location.hostname;
\tif (host.indexOf(':') !== -1 && host.charAt(0) !== '[') {
\t\thost = '[' + host + ']';
\t}
\tvar targetUrl = 'http://' + host + ':8001/';

\tvar btn = document.getElementById('modemwebui-open-btn');
\tvar link = document.getElementById('modemwebui-url-link');
\tvar statusEl = document.getElementById('modemwebui-status');

\tif (btn) btn.href = targetUrl;
\tif (link) {
\t\tlink.href = targetUrl;
\t\tlink.textContent = targetUrl;
\t}

\tvar win = null;
\ttry {
\t\twin = window.open(targetUrl, '_blank');
\t\tif (win) {
\t\t\ttry { win.opener = null; } catch (e) {}
\t\t}
\t} catch (e) {
\t\twin = null;
\t}

\tif (statusEl) {
\t\tstatusEl.textContent = win
\t\t\t? '已尝试在新窗口打开 ModemWebUI；若未自动切换，请点击下方按钮。'
\t\t\t: '浏览器已拦截自动弹窗，请点击下方按钮在新窗口打开 ModemWebUI。';
\t}
})();
</script>
<%+footer%>
"""
with open(view_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(new_view)

# 7. Add LuCI preload hook so Modem -> ModemWebUI opens http://<host>:8001/ directly in a new tab
preload_path = "package/luci-app-modemwebui/www/luci-static/resources/preload/modemwebui.js"
os.makedirs(os.path.dirname(preload_path), exist_ok=True)
preload_js = """'use strict';
'require baseclass';
'require ui';

return baseclass.extend({
\t__init__: function() {
\t\tvar host = window.location.hostname;
\t\tif (host.indexOf(':') !== -1 && host.charAt(0) !== '[')
\t\t\thost = '[' + host + ']';
\t\tvar targetUrl = 'http://' + host + ':8001/';
\t\tvar pathRe = /\\/admin\\/modem\\/modemwebui\\/?$/;

\t\tfunction patchLinks(root) {
\t\t\tvar links = (root || document).querySelectorAll('a[href]');
\t\t\tvar found = false;
\t\t\tfor (var i = 0; i < links.length; i++) {
\t\t\t\tvar a = links[i];
\t\t\t\tvar href = a.getAttribute('href') || '';
\t\t\t\tif (a.dataset.modemwebuiPatched === '1') {
\t\t\t\t\tfound = true;
\t\t\t\t\tcontinue;
\t\t\t\t}
\t\t\t\tif (pathRe.test(href)) {
\t\t\t\t\ta.href = targetUrl;
\t\t\t\t\ta.target = '_blank';
\t\t\t\t\ta.rel = 'noopener noreferrer';
\t\t\t\t\ta.dataset.modemwebuiPatched = '1';
\t\t\t\t\tfound = true;
\t\t\t\t}
\t\t\t}
\t\t\treturn found;
\t\t}

\t\t// Race-free fallback if user clicks before menu link is rewritten
\t\tdocument.addEventListener('click', function(ev) {
\t\t\tif (ev.defaultPrevented || ev.button !== 0 || ev.metaKey || ev.ctrlKey || ev.shiftKey || ev.altKey)
\t\t\t\treturn;
\t\t\tvar a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
\t\t\tif (!a || a.dataset.modemwebuiPatched === '1')
\t\t\t\treturn;
\t\t\tvar href = a.getAttribute('href') || '';
\t\t\tif (pathRe.test(href)) {
\t\t\t\tev.preventDefault();
\t\t\t\twindow.open(targetUrl, '_blank', 'noopener,noreferrer');
\t\t\t}
\t\t}, true);

\t\tpatchLinks(document);

\t\tvar obsTarget = document.getElementById('topmenu') || document.getElementById('mainmenu') || document.body;
\t\tvar observer = null;
\t\tif (obsTarget && typeof MutationObserver === 'function') {
\t\t\tobserver = new MutationObserver(function() {
\t\t\t\tpatchLinks(document);
\t\t\t});
\t\t\tobserver.observe(obsTarget, { childList: true, subtree: true });
\t\t\twindow.setTimeout(function() {
\t\t\t\tif (observer) {
\t\t\t\t\tobserver.disconnect();
\t\t\t\t\tobserver = null;
\t\t\t\t}
\t\t\t}, 10000);
\t\t}

\t\tif (ui && ui.menu && typeof ui.menu.load === 'function') {
\t\t\tui.menu.load().then(function() {
\t\t\t\twindow.setTimeout(function() {
\t\t\t\t\tif (patchLinks(document) && observer) {
\t\t\t\t\t\tobserver.disconnect();
\t\t\t\t\t\tobserver = null;
\t\t\t\t\t}
\t\t\t\t}, 0);
\t\t\t}).catch(function() {});
\t\t}
\t}
});
"""
with open(preload_path, "w", encoding="utf-8", newline="\n") as f:
    f.write(preload_js)
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
patch_file(
    "package/smsforward/smsforward.c",
    r"""// HTTP POST通用函数 - 使用wget替代libcurl（节省2-3MB内存）
int send_http_post(const char *url, const char *json_data, char *response_buffer) {
    FILE *fp;
    char *cmd;
    int result;
    size_t cmd_size;
    
    // 动态分配命令缓冲区
    cmd_size = strlen(url) + strlen(json_data) + 256;
    cmd = malloc(cmd_size);
    if (!cmd) {
        return -1;
    }
    
    // 构建wget命令
    snprintf(cmd, cmd_size,
        "wget --post-data='%s' "
        "--header='Content-Type: application/json' "
        "--timeout=10 --tries=1 -4 -q -O- '%s' 2>/dev/null",
        json_data, url);
    
    // 执行命令
    fp = popen(cmd, "r");
    free(cmd);
    
    if (!fp) {
        return -1;
    }
    
    // 读取响应
    if (response_buffer) {
        size_t n = fread(response_buffer, 1, 2047, fp);
        response_buffer[n] = '\0';
    }
    
    result = pclose(fp);
    return (result == 0) ? 0 : -1;
}""",
    r"""// HTTP POST通用函数 - 使用curl替代wget(uclient-fetch不支持--tries)并通过临时文件传参防止单引号破坏JSON
int send_http_post(const char *url, const char *json_data, char *response_buffer) {
    char tmp_path[] = "/tmp/smsfwd_XXXXXX";
    char drain[256];
    int tmp_fd;
    size_t len, written = 0;
    char *cmd;
    size_t cmd_size;
    FILE *fp;
    int result;

    if (!url || !json_data || strchr(url, '\'')) {
        return -1;
    }

    tmp_fd = mkstemp(tmp_path);
    if (tmp_fd < 0) {
        return -1;
    }

    len = strlen(json_data);
    while (written < len) {
        ssize_t w = write(tmp_fd, json_data + written, len - written);
        if (w < 0) {
            if (errno == EINTR) continue;
            close(tmp_fd);
            unlink(tmp_path);
            return -1;
        }
        written += (size_t)w;
    }
    close(tmp_fd);

    cmd_size = strlen(url) + sizeof(tmp_path) + 192;
    cmd = malloc(cmd_size);
    if (!cmd) {
        unlink(tmp_path);
        return -1;
    }

    snprintf(cmd, cmd_size,
        "curl -fsSL -4 --connect-timeout 10 --max-time 15 "
        "-H 'Content-Type: application/json' "
        "--data-binary '@%s' '%s' 2>/dev/null",
        tmp_path, url);

    fp = popen(cmd, "r");
    free(cmd);

    if (!fp) {
        unlink(tmp_path);
        return -1;
    }

    if (response_buffer) {
        size_t n = fread(response_buffer, 1, 2047, fp);
        response_buffer[n] = '\0';
    }
    while (fread(drain, 1, sizeof(drain), fp) > 0) {}

    result = pclose(fp);
    unlink(tmp_path);
    return (result == 0) ? 0 : -1;
}""",
)
patch_file(
    "package/smsforward/smsforward.c",
    r"""        // 先获取短信存储数量（快速检查）
        int storage_count = -1;
        if (get_sms_storage_count(resolved_port, &storage_count) != 0) {
            printf("获取存储数量失败，跳过本轮。\n");
            sleep(13);
            continue;
        }""",
    r"""        // 先获取短信存储数量（快速检查）
        int storage_count = -1;
        if (get_sms_storage_count(resolved_port, &storage_count) != 0) {
            char new_port[64];
            if (resolve_at_port(new_port, sizeof(new_port)) == 0 && strcmp(new_port, resolved_port) != 0) {
                printf("检测到串口变更: %s -> %s，自动切换。\n", resolved_port, new_port);
                snprintf(resolved_port, sizeof(resolved_port), "%s", new_port);
                continue;
            }
            printf("获取存储数量失败，跳过本轮。\n");
            sleep(13);
            continue;
        }""",
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

# 4. qmodem modem_hook.sh: reload modemwebui after post_init updates at_port (before exec qmodem-settings)
modem_hook = "feeds/qmodem/application/qmodem/files/usr/share/qmodem/modem_hook.sh"
with open(modem_hook, "r", encoding="utf-8", newline="") as f:
    hook_text = f.read().replace("\r\n", "\n")
old_hook = (
    "    post_init)\n"
    "        # pre-add at commands\n"
    '        cfg_prefix="post_init"\n'
    '        debug_subject="post_init"\n'
    "\t\tif [ -x /usr/sbin/qmodem-settings ]; then\n"
)
new_hook = (
    "    post_init)\n"
    "        # pre-add at commands\n"
    '        cfg_prefix="post_init"\n'
    '        debug_subject="post_init"\n'
    "        if [ -x /etc/init.d/modemwebui ] && { /etc/init.d/modemwebui enabled 2>/dev/null || [ -L /etc/rc.d/S99modemwebui ]; }; then\n"
    "            (/etc/init.d/modemwebui reload </dev/null >/dev/null 2>&1) &\n"
    "        fi\n"
    "\t\tif [ -x /usr/sbin/qmodem-settings ]; then\n"
)
assert old_hook in hook_text, f"Target post_init block not found in {modem_hook}"
hook_text = hook_text.replace(old_hook, new_hook, 1)
with open(modem_hook, "w", encoding="utf-8", newline="\n") as f:
    f.write(hook_text)
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

# 3. Pre-install official prebuilt llvm-bpf toolchain (avoids 70-min LLVM source build & runner OOM)
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

# 6.5 Configure sbwml MosDNS v5 (prioritize patched mosdns + geo2txt + luci-app-mosdns over upstream packages feed)
echo "Configuring sbwml MosDNS v5..."
rm -rf feeds/packages/net/mosdns package/feeds/packages/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns package/feeds/luci/luci-app-mosdns
./scripts/feeds install -a -f -p mosdns
[ -f package/feeds/mosdns/mosdns/Makefile ] && [ -f package/feeds/mosdns/geo2txt/Makefile ] && [ -f package/feeds/mosdns/luci-app-mosdns/Makefile ] || exit 1

# 7. Clean up removed plugins (honk, daede, momo, mt5700m, openlist) to prevent leftover builds
rm -rf package/honk package/luci-app-honk package/luci-lib-daeuniverse
rm -rf package/daede
rm -rf package/openlist feeds/packages/net/openlist package/feeds/packages/openlist feeds/luci/applications/luci-app-openlist package/feeds/luci/luci-app-openlist
rm -rf feeds/momo package/feeds/momo package/momo package/luci-app-momo
rm -rf package/luci-app-mt5700m feeds/luci/applications/luci-app-mt5700m package/feeds/luci/luci-app-mt5700m
rm -rf feeds/packages/net/dae feeds/packages/net/daed feeds/luci/applications/luci-app-dae feeds/luci/applications/luci-app-daed
rm -rf package/feeds/packages/dae package/feeds/packages/daed package/feeds/luci/luci-app-dae package/feeds/luci/luci-app-daed

echo "DIY Part 2 setup completed successfully."
