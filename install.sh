#!/usr/bin/env bash
# ====================================================================
# Aio-box Ultimate Console [Sing-box Native & Nuclear Port Force]
# Version: 2026.04.Apex-Stable-V39-Final
# ====================================================================

export DEBIAN_FRONTEND=noninteractive
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;36m' PURPLE='\033[0;35m' CYAN='\033[0;36m' NC='\033[0m' BOLD='\033[1m'

# --- [0] 自动提权 ---
[[ $EUID -ne 0 ]] && { exec sudo bash "$0" "$@"; exit 0; }
sed -i '/acme.sh.env/d' ~/.bashrc >/dev/null 2>&1 || true

# --- [1] 环境初始化 ---
setup_shortcut() {
    mkdir -p /etc/ddr
    [[ ! -f /etc/ddr/aio.sh || "$1" == "update" ]] && { curl -Ls https://raw.githubusercontent.com/alariclin/aio-box/main/install.sh > /etc/ddr/aio.sh; chmod +x /etc/ddr/aio.sh; }
    [[ ! -f /usr/local/bin/sb ]] && { printf '#!/bin/bash\nsudo bash /etc/ddr/aio.sh "$@"\n' > /usr/local/bin/sb; chmod +x /usr/local/bin/sb; }
}

check_env() {
    echo -e "${YELLOW}[*] 正在同步系统依赖环境...${NC}"
    apt-get update -y -q || yum makecache -y -q
    local deps=(wget curl jq openssl uuid-runtime cron fail2ban python3 bc unzip vnstat iptables tar psmisc lsof)
    if command -v apt-get >/dev/null; then apt-get install -y -q "${deps[@]}"; else yum install -y -q "${deps[@]}"; fi
    systemctl enable cron vnstat 2>/dev/null || true; systemctl start cron vnstat 2>/dev/null || true
}

get_architecture() {
    local ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && { X_ARCH="64"; S_ARCH="amd64"; } || { X_ARCH="arm64-v8a"; S_ARCH="arm64"; }
}

fetch_github() {
    local repo=$1; local key=$2; local out=$3
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local url=$(curl -sL "$api" | jq -r ".assets[] | select(.name | contains(\"$key\")) | .browser_download_url" | head -n 1)
    [[ -z "$url" || "$url" == "null" ]] && url=$(curl -sL "https://ghp.ci/$api" | jq -r ".assets[] | select(.name | contains(\"$key\")) | .browser_download_url" | head -n 1)
    curl -fLs --connect-timeout 15 "$url" -o "/tmp/$out" || { echo -e "${RED}[!] 核心拉取失败${NC}"; exit 1; }
}

pre_install_setup() {
    local MODE=$1
    AUTO_REALITY="www.microsoft.com"
    echo -e "\n${CYAN}======================================================================${NC}"
    echo -e "${BOLD}🚀 部署前向导：正统 443 端口部署方案${NC}"
    echo -e "   强制使用高防 SNI: ${GREEN}$AUTO_REALITY${NC}"
    echo -e "${BLUE}----------------------------------------------------------------------${NC}"
    read -ep "   请输入伪装 SNI (直接回车默认使用微软): " IV_SNI; VLESS_SNI=${IV_SNI:-$AUTO_REALITY}
    read -ep "   请输入监听端口 (直接回车默认使用 443): " IV_PORT; VLESS_PORT=${IV_PORT:-443}
    HY2_SNI=$VLESS_SNI; HY2_PORT=$VLESS_PORT; SS_PORT=2053
    echo -e "${CYAN}======================================================================${NC}\n"
}

# --- 物理层套接字核弹清理 ---
release_ports() {
    echo -e "${YELLOW}[*] 正在执行内核级端口强制绞杀，根除 bind 死锁...${NC}"
    systemctl stop xray sing-box hysteria 2>/dev/null || true
    killall -9 xray sing-box hysteria 2>/dev/null || true
    local ports_to_clean=($VLESS_PORT $HY2_PORT $SS_PORT)
    for p in "${ports_to_clean[@]}"; do
        fuser -k -9 ${p}/tcp 2>/dev/null || true
        fuser -k -9 ${p}/udp 2>/dev/null || true
        lsof -ti:${p} | xargs kill -9 2>/dev/null || true
    done
    sleep 2
}

# --- 部署 Sing-box (原生完美支持 Hy2 + Reality) ---
deploy_singbox() {
    local MODE=$1; clear; echo -e "${BOLD}${GREEN} 部署 Sing-box [$MODE] ${NC}"; check_env; pre_install_setup "$MODE"
    release_ports; get_architecture
    fetch_github "SagerNet/sing-box" "linux-${S_ARCH}.tar.gz" "sb.tar.gz"
    tar -xzf "/tmp/sb.tar.gz" -C /tmp; mv /tmp/sing-box-*/sing-box /usr/local/bin/; chmod +x /usr/local/bin/sing-box
    
    PK=$(/usr/local/bin/sing-box generate reality-keypair | grep "Private" | awk '{print $NF}')
    PBK=$(/usr/local/bin/sing-box generate reality-keypair | grep "Public" | awk '{print $NF}')
    UUID=$(uuidgen); SID=$(openssl rand -hex 4); SS_PASS=$(openssl rand -base64 16 | tr -d '\n\r')
    HY2_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9'); HY2_OBFS=$(openssl rand -base64 8 | tr -dc 'a-zA-Z0-9')
    
    mkdir -p /etc/sing-box; openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/hy2.key 2>/dev/null
    openssl req -new -x509 -days 36500 -key /etc/sing-box/hy2.key -out /etc/sing-box/hy2.crt -subj "/CN=$HY2_SNI" 2>/dev/null

    JSON_V='{ "type": "vless", "listen": "::", "listen_port": '$VLESS_PORT', "tcp_fast_open": true, "users": [{"uuid": "'$UUID'", "flow": "xtls-rprx-vision"}], "tls": { "enabled": true, "server_name": "'$VLESS_SNI'", "reality": { "enabled": true, "handshake": { "server": "'$VLESS_SNI'", "server_port": 443 }, "private_key": "'$PK'", "short_id": ["'$SID'"] } } }'
    JSON_H='{ "type": "hysteria2", "listen": "::", "listen_port": '$HY2_PORT', "up_mbps": 3000, "down_mbps": 3000, "obfs": { "type": "salamander", "password": "'$HY2_OBFS'" }, "users": [{"password": "'$HY2_PASS'"}], "tls": { "enabled": true, "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" } }'
    JSON_S='{ "type": "shadowsocks", "listen": "::", "listen_port": '$SS_PORT', "tcp_fast_open": true, "method": "2022-blake3-aes-128-gcm", "password": "'$SS_PASS'" }'

    case $MODE in "VLESS") IN="[$JSON_V]" ;; "HY2") IN="[$JSON_H]" ;; "SS") IN="[$JSON_S]" ;; "ALL") IN="[$JSON_V, $JSON_H, $JSON_S]" ;; esac
    echo '{ "log": { "level": "warn" }, "inbounds": '$IN', "outbounds": [{ "type": "direct" }] }' > /etc/sing-box/config.json

    cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
After=network.target
[Service]
ExecStartPre=-/bin/sh -c '/sbin/iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $HY2_PORT 2>/dev/null || true'
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
ExecStopPost=-/bin/sh -c '/sbin/iptables -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $HY2_PORT 2>/dev/null || true'
Restart=always
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now sing-box; systemctl restart sing-box
    sleep 2; systemctl is-active --quiet sing-box || { echo -e "${RED}[!] 致命错误：Sing-box 无法启动。${NC}"; journalctl -u sing-box --no-pager -n 20; exit 1; }

    IP=$(curl -s4 api.ipify.org)
    cat > /etc/ddr/.env << ENV_EOF
CORE="singbox"; MODE="$MODE"; UUID="$UUID"; VLESS_SNI="$VLESS_SNI"; VLESS_PORT="$VLESS_PORT"; HY2_SNI="$HY2_SNI"; HY2_PORT="$HY2_PORT"; SS_PORT="$SS_PORT"; PUBLIC_KEY="$PBK"; SHORT_ID="$SID"; HY2_PASS="$HY2_PASS"; HY2_OBFS="$HY2_OBFS"; SS_PASS="$SS_PASS"; LINK_IP="$IP"
ENV_EOF
    view_config "deploy"
}

# --- 部署 Xray (不推荐用于 Hy2，仅作保留) ---
deploy_xray() {
    local MODE=$1; clear; echo -e "${BOLD}${GREEN} 部署 Xray-core [$MODE] ${NC}"; check_env; pre_install_setup "$MODE"; release_ports; get_architecture
    fetch_github "XTLS/Xray-core" "Xray-linux-${X_ARCH}.zip" "xray.zip"
    rm -rf /tmp/xext; unzip -qo "/tmp/xray.zip" -d /tmp/xext; mv /tmp/xext/xray /usr/local/bin/xray; chmod +x /usr/local/bin/xray
    PK=$(/usr/local/bin/xray x25519 | grep "Private" | awk '{print $NF}'); PBK=$(/usr/local/bin/xray x25519 | grep "Public" | awk '{print $NF}')
    UUID=$(uuidgen); SID=$(openssl rand -hex 4); SS_PASS=$(openssl rand -base64 16 | tr -d '\n\r')
    mkdir -p /usr/local/share/xray /usr/local/etc/xray
    fetch_geo_data "geoip.dat" "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"; mv /tmp/geoip.dat /usr/local/share/xray/
    fetch_geo_data "geosite.dat" "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"; mv /tmp/geosite.dat /usr/local/share/xray/
    
    JSON_V='{ "listen": "0.0.0.0", "port": '$VLESS_PORT', "protocol": "vless", "settings": { "clients": [{"id": "'$UUID'", "flow": "xtls-rprx-vision"}], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "realitySettings": { "dest": "'$VLESS_SNI':443", "serverNames": ["'$VLESS_SNI'"], "privateKey": "'$PK'", "shortIds": ["'$SID'"] } } }'
    JSON_S='{ "listen": "0.0.0.0", "port": '$SS_PORT', "protocol": "shadowsocks", "settings": { "method": "2022-blake3-aes-128-gcm", "password": "'$SS_PASS'", "network": "tcp,udp" } }'
    case $MODE in "VLESS") IN="[$JSON_V]" ;; "SS") IN="[$JSON_S]" ;; "ALL") IN="[$JSON_V, $JSON_S]" ;; esac
    echo '{ "log": { "loglevel": "warning" }, "inbounds": '$IN', "outbounds": [{ "protocol": "freedom" }] }' > /usr/local/etc/xray/config.json

    cat > /etc/systemd/system/xray.service << EOF
[Unit]
After=network.target
[Service]
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=always
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now xray; systemctl restart xray
    sleep 2; systemctl is-active --quiet xray || { echo -e "${RED}[!] 致命错误：Xray 核心启动失败！${NC}"; exit 1; }
    IP=$(curl -s4 api.ipify.org)
    cat > /etc/ddr/.env << ENV_EOF
CORE="xray"; MODE="$MODE"; UUID="$UUID"; VLESS_SNI="$VLESS_SNI"; VLESS_PORT="$VLESS_PORT"; SS_PORT="$SS_PORT"; PUBLIC_KEY="$PBK"; SHORT_ID="$SID"; SS_PASS="$SS_PASS"; LINK_IP="$IP"
ENV_EOF
    view_config "deploy"
}

view_config() {
    local CALLER=$1; clear; [[ ! -f /etc/ddr/.env ]] && return 0; source /etc/ddr/.env
    echo -e "${BLUE}======================================================================${NC}\n${BOLD}${CYAN}   协议全部节点参数 (${CORE} - ${MODE}) ${NC}\n${BLUE}======================================================================${NC}"
    [[ "$MODE" == *"VLESS"* || "$MODE" == *"ALL"* ]] && echo -e "${YELLOW}[ VLESS-Vision (小火箭请选 uTLS: chrome) ]${NC}\nvless://$UUID@$LINK_IP:$VLESS_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$VLESS_SNI&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#Aio-VLESS\n"
    [[ "$CORE" == "singbox" ]] && [[ "$MODE" == *"HY2"* || "$MODE" == *"ALL"* ]] && echo -e "${YELLOW}[ Hysteria 2 (小火箭务必开启 允许不安全) ]${NC}\nhysteria2://$HY2_PASS@$LINK_IP:$HY2_PORT/?insecure=1&sni=$HY2_SNI&alpn=h3&obfs=salamander&obfs-password=$HY2_OBFS&mport=20000-50000#Aio-Hy2\n"
    [[ "$MODE" == *"SS"* || "$MODE" == *"ALL"* ]] && echo -e "${YELLOW}[ Shadowsocks ]${NC}\nss://$(echo -n "2022-blake3-aes-128-gcm:$SS_PASS" | base64 | tr -d '\n\r')@$LINK_IP:$SS_PORT#Aio-SS\n"
    [[ "$CALLER" == "deploy" ]] && echo -e "${GREEN}✔ 部署成功！${NC}"
    read -ep "按回车返回主菜单..."
}

clean_uninstall() {
    clear; echo -e "${RED}⚠️  核弹级卸载交互向导${NC}\n 1. 仅删除核心与配置\n 2. 彻底物理清场 (恢复处女态)"
    read -ep " 请选择 [1-2]: " clean_choice
    echo -e "${YELLOW}[*] 暴力绞杀进程与网络链条...${NC}"
    systemctl stop xray sing-box hysteria 2>/dev/null || true
    killall -9 xray sing-box hysteria 2>/dev/null || true
    iptables -t nat -F PREROUTING 2>/dev/null || true
    ip6tables -t nat -F PREROUTING 2>/dev/null || true
    rm -rf /usr/local/etc/xray /etc/sing-box /usr/local/bin/xray /usr/local/bin/sing-box /etc/systemd/system/xray.service /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    if [[ "$clean_choice" == "2" ]]; then rm -rf /etc/ddr /usr/local/bin/sb; echo -e "${GREEN}✔ 彻底清场完毕！${NC}"; exit 0; else rm -f /etc/ddr/.env; echo -e "${GREEN}✔ 清理完成。${NC}"; sleep 2; fi
}

setup_shortcut
while true; do
    IPV4=$(curl -s4m3 api.ipify.org || echo "N/A"); systemctl is-active --quiet xray && STATUS="${GREEN}Running (Xray)${NC}" || { systemctl is-active --quiet sing-box && STATUS="${CYAN}Running (Sing-box)${NC}" || STATUS="${RED}Stopped${NC}"; }
    source /etc/ddr/.env 2>/dev/null && CUR_MODE="[${CORE}-${MODE}]" || CUR_MODE=""
    clear; echo -e "${BLUE}======================================================================${NC}\n${BOLD}${PURPLE}  Aio-box Ultimate Console [Apex V39 Final] ${NC}\n${BLUE}======================================================================${NC}"
    echo -e " IP: ${YELLOW}$IPV4${NC} | STATUS: $STATUS $CUR_MODE\n${BLUE}----------------------------------------------------------------------${NC}"
    echo -e " ${YELLOW}[ Xray-core (不支持Hy2) ]${NC}     ${CYAN}[ Sing-box (完美支持Hy2) ]${NC}"
    echo -e " ${GREEN}1.${NC} VLESS-Vision (REALITY)      ${GREEN}5.${NC} VLESS-Vision (REALITY)"
    echo -e " ${GREEN}3.${NC} Shadowsocks                 ${GREEN}6.${NC} Hysteria 2"
    echo -e " ${GREEN}4.${NC} 协议全家桶 (VLESS+SS)       ${GREEN}7.${NC} Shadowsocks\n                                 ${GREEN}8.${NC} 协议全家桶 (VLESS+HY2+SS)"
    echo -e "${BLUE}----------------------------------------------------------------------${NC}"
    echo -e " ${RED}15.${NC} 彻底清空卸载 / Clean Purge  ${GREEN}0.${NC}  退出面板 / Exit Dashboard"
    echo -e "${BLUE}======================================================================${NC}"
    read -ep " 请选择: " choice
    case $choice in
        1) deploy_xray "VLESS" ;; 3) deploy_xray "SS" ;; 4) deploy_xray "ALL" ;;
        5) deploy_singbox "VLESS" ;; 6) deploy_singbox "HY2" ;; 7) deploy_singbox "SS" ;; 8) deploy_singbox "ALL" ;;
        15) clean_uninstall ;; 0) clear; exit 0 ;;
    esac
done
