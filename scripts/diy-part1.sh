#!/bin/bash
# =================================================================
# DIY script part 1 (Before feeds update)
# Description: Add extra custom feeds to feeds.conf.default
# =================================================================

# 1. Add QModem feed for 5G AT daemon and SMS tools (ubus-at-daemon, sms-tool_q)
sed -i '/qmodem/d' feeds.conf.default
echo 'src-git qmodem https://github.com/FUjr/QModem.git;main' >> feeds.conf.default
