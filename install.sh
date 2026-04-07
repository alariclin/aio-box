#!/usr/bin/env bash
# ====================================================================
# Aio-box Ultimate Console [Full Features | Shortcut 'sb']
# ====================================================================

export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m' BLUE='\033[0;36m' PURPLE='\033[0;35m' CYAN='\033[0;36m' NC='\033[0m' BOLD='\033[1m'

# --- [0] 自动提权引擎与环境清理 ---
if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo bash "$0" "$@"
    else
        echo -e "${RED}[!] 必须使用 Root 权限运行此控制台！请执行 'sudo su -'${NC}"
        exit 1
    fi
fi
sed -i '/acme.sh.env/d' ~/.bashrc >/dev/null 2>&1 || true
USER_MIRROR_BASE="https://raw.githubusercontent.com/alariclin/aio-box/main/core"

# --- [1] 本地化快捷指令与环境准备 ---
setup_shortcut() {
    mkdir -p /etc/ddr
    if [[ ! -f /etc/ddr/aio.sh || "$1" == "update" ]]; then
        curl -Ls https://raw.githubusercontent.com/alariclin/aio-box/main/install.sh > /etc/ddr/aio.sh
        chmod +x /etc/ddr/aio.sh
    fi
    if [[ ! -f /usr/local/bin/sb ]]; then
        echo '#!/bin/bash' > /usr/local/bin/sb
        echo 'sudo bash /etc/ddr/aio.sh "$@"' >> /usr/local/bin/sb
        chmod +x /usr/local/bin/sb
    fi
    return 0
}

check_env() {
    if ! command -v jq >/dev/null || ! command -v unzip >/dev/null || ! command -v iptables >/dev/null; then
        echo -e "${YELLOW}[*] 正在同步系统依赖环境... / Syncing dependencies...${NC}"
        apt-get update -y -q || yum makecache -y -q
        apt-get install -y -q wget curl jq openssl uuid-runtime cron fail2ban python3 bc unzip vnstat iptables || \
        yum install -y -q wget curl jq openssl uuid-runtime cronie fail2ban python3 bc unzip vnstat iptables
        systemctl enable cron vnstat 2>/dev/null || systemctl enable cronie vnstat 2>/dev/null
        systemctl start cron vnstat 2>/dev/null || systemctl start cronie vnstat 2>/dev/null
    fi
    return 0
}

fetch_core() {
    local file_name=$1; local official_url=$2; local cache_dir="/etc/ddr/.core_cache"
    mkdir -p "$cache_dir"
    if [[ -f "${cache_dir}/${file_name}" ]]; then
        echo -e "${GREEN} -> 提取本地缓存 / Extracting local cache [${file_name}]...${NC}"; cp "${cache_dir}/${file_name}" "/tmp/${file_name}"; return 0
    fi
    echo -e "${YELLOW} -> 拉取云端资源 / Fetching from cloud [${file_name}]...${NC}"
    local mirrors=("" "https://ghp.ci/" "https://ghproxy.net/" "https://mirror.ghproxy.com/")
    for mirror in "${mirrors[@]}"; do
        if curl -fL --connect-timeout 10 "${mirror}${official_url}" -o "/tmp/${file_name}" 2>/dev/null; then
            if [[ -s "/tmp/${file_name}" ]]; then
                cp "/tmp/${file_name}" "${cache_dir}/${file_name}"
                echo -e "${GREEN}   ✔ 获取成功！ / Download successful!${NC}"; return 0
            fi
        fi
    done
    if curl -fL --connect-timeout 10 "${USER_MIRROR_BASE}/${file_name}" -o "/tmp/${file_name}" 2>/dev/null; then
        if [[ -s "/tmp/${file_name}" ]]; then
            cp "/tmp/${file_name}" "${cache_dir}/${file_name}"
            echo -e "${GREEN}   ✔ 备份源提取成功！ / Backup mirror fetch successful!${NC}"; return 0
        fi
    fi
    echo -e "${RED}[!] 下载彻底失败 / Fetch failed.${NC}"; exit 1
}

# 部署前向导：动态获取 SNI 与端口
pre_install_setup() {
    ASN_ORG=$(curl -sm3 "ipinfo.io/org" || echo "GENERIC")
    ASN_UPPER=$(echo "$ASN_ORG" | tr '[:lower:]' '[:upper:]')
    if [[ "$ASN_UPPER" == *"GOOGLE"* ]]; then AUTO_REALITY="storage.googleapis.com"
    elif [[ "$ASN_UPPER" == *"AMAZON"* || "$ASN_UPPER" == *"AWS"* ]]; then AUTO_REALITY="s3.amazonaws.com"
    elif [[ "$ASN_UPPER" == *"MICROSOFT"* || "$ASN_UPPER" == *"AZURE"* ]]; then AUTO_REALITY="dl.delivery.mp.microsoft.com"
    else AUTO_REALITY="www.microsoft.com"; fi

    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${BOLD}1. 伪装域名设置 / SNI Setup${NC}"
    echo -e "   系统推荐防封 SNI: ${GREEN}$AUTO_REALITY${NC}"
    echo -e "   (支持输入您托管在 Cloudflare 等平台的自有域名 / Supports your own domain)"
    read -ep "   请输入自定义 SNI (直接回车默认推荐值): " INPUT_SNI
    REALITY_SNI=${INPUT_SNI:-$AUTO_REALITY}

    echo -e "\n${BOLD}2. 物理端口设置 / Port Setup${NC}"
    read -ep "   请输入 VLESS/Hy2 主监听端口 (直接回车默认 443): " INPUT_PORT
    MAIN_PORT=${INPUT_PORT:-443}

    read -ep "   请输入 Shadowsocks 备用端口 (直接回车默认 2053): " INPUT_SS_PORT
    SS_PORT=${INPUT_SS_PORT:-2053}
    echo -e "${CYAN}======================================================${NC}\n"
    return 0
}

# --- [2] 部署逻辑 (Xray / Sing-box) ---
deploy_xray() {
    local MODE=$1
    clear; echo -e "${BOLD}${GREEN} 部署 Xray-core [$MODE] ${NC}"; check_env
    pre_install_setup
    
    systemctl disable --now sing-box 2>/dev/null || true
    systemctl stop xray 2>/dev/null || true
    
    XRAY_VER="v26.3.27"; ARCH=$(uname -m | sed 's/x86_64/64/;s/aarch64/arm64-v8a/')
    fetch_core "Xray-linux-${ARCH}.zip" "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-${ARCH}.zip"
    fetch_core "geoip.dat" "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
    fetch_core "geosite.dat" "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"
    
    rm -rf /tmp/xray_ext; unzip -qo "/tmp/Xray-linux-${ARCH}.zip" -d /tmp/xray_ext
    mv /tmp/xray_ext/xray /usr/local/bin/xray; chmod +x /usr/local/bin/xray
    mkdir -p /usr/local/share/xray /usr/local/etc/xray
    mv /tmp/geoip.dat /usr/local/share/xray/; mv /tmp/geosite.dat /usr/local/share/xray/

    KEYS=$(/usr/local/bin/xray x25519 2>&1 || true)
    PK=$(echo "$KEYS" | grep -i "Private" | awk '{print $NF}'); PBK=$(echo "$KEYS" | grep -i "Public" | awk '{print $NF}')
    if [[ -z "$PK" ]]; then echo -e "${RED}[!] 核心不兼容 / Core incompatible.${NC}"; exit 1; fi

    UUID=$(uuidgen); SHORT_ID=$(openssl rand -hex 4)
    SS_PASS=$(openssl rand -base64 16 | tr -d '\n\r'); HY2_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9'); HY2_OBFS=$(openssl rand -base64 8 | tr -dc 'a-zA-Z0-9')
    
    mkdir -p /usr/local/etc/xray; openssl ecparam -genkey -name prime256v1 -out /usr/local/etc/xray/hy2.key 2>/dev/null
    openssl req -new -x509 -days 36500 -key /usr/local/etc/xray/hy2.key -out /usr/local/etc/xray/hy2.crt -subj "/CN=${REALITY_SNI}" 2>/dev/null

    JSON_VLESS='{ "port": '$MAIN_PORT', "protocol": "vless", "settings": { "clients": [{"id": "'$UUID'", "flow": "xtls-rprx-vision"}], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "realitySettings": { "dest": "'$REALITY_SNI':443", "serverNames": ["'$REALITY_SNI'"], "privateKey": "'$PK'", "shortIds": ["'$SHORT_ID'"] } } }'
    JSON_HY2='{ "port": '$MAIN_PORT', "protocol": "hysteria", "tag": "hy2-in", "settings": { "clients": [{"password": "'$HY2_PASS'"}] }, "streamSettings": { "security": "tls", "tlsSettings": { "alpn": ["h3"], "certificates": [{ "certificateFile": "/usr/local/etc/xray/hy2.crt", "keyFile": "/usr/local/etc/xray/hy2.key" }] }, "hysteriaSettings": { "version": 2, "obfs": "salamander", "obfsPassword": "'$HY2_OBFS'" } } }'
    JSON_SS='{ "port": '$SS_PORT', "protocol": "shadowsocks", "settings": { "method": "2022-blake3-aes-128-gcm", "password": "'$SS_PASS'", "network": "tcp,udp" } }'

    case $MODE in
        "VLESS") INBOUNDS="[$JSON_VLESS]" ;;
        "HY2") INBOUNDS="[$JSON_HY2]" ;;
        "SS") INBOUNDS="[$JSON_SS]" ;;
        "ALL") INBOUNDS="[$JSON_VLESS, $JSON_HY2, $JSON_SS]" ;;
    esac

    cat > /usr/local/etc/xray/config.json << EOF
{ "log": { "loglevel": "warning" }, "inbounds": $INBOUNDS, "outbounds": [{ "protocol": "freedom" }] }
EOF

    IPT=$(command -v iptables || echo "/sbin/iptables")
    IP6=$(command -v ip6tables || echo "/sbin/ip6tables")

    cat > /etc/systemd/system/xray.service << SVC_EOF
[Unit]
After=network.target
[Service]
ExecStartPre=-$IPT -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStartPre=-$IP6 -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStartPre=-$IPT -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStartPre=-$IP6 -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
ExecStopPost=-$IPT -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStopPost=-$IP6 -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
Restart=always
LimitNOFILE=1048576
LimitNPROC=infinity
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable --now xray; systemctl restart xray
    
    sleep 1
    if ! systemctl is-active --quiet xray; then
        echo -e "${RED}[!] 致命错误：Xray 核心无法启动！ / Fatal Error: Core failed to start!${NC}"
        journalctl -u xray --no-pager -n 10; exit 1
    fi

    cat > /etc/ddr/.env << ENV_EOF
CORE="xray"
MODE="$MODE"
UUID="$UUID"
REALITY_SNI="$REALITY_SNI"
MAIN_PORT="$MAIN_PORT"
SS_PORT="$SS_PORT"
PUBLIC_KEY="$PBK"
SHORT_ID="$SHORT_ID"
HY2_PASS="$HY2_PASS"
HY2_OBFS="$HY2_OBFS"
SS_PASS="$SS_PASS"
LINK_IP="$PUBLIC_IP"
ENV_EOF
    view_config "deploy"
}

deploy_singbox() {
    local MODE=$1
    clear; echo -e "${BOLD}${GREEN} 部署 Sing-box [$MODE] ${NC}"; check_env
    pre_install_setup

    systemctl disable --now xray 2>/dev/null || true
    systemctl stop sing-box 2>/dev/null || true

    SB_VER="1.13.6"; ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    fetch_core "sing-box-${SB_VER}-linux-${ARCH}.tar.gz" "https://github.com/SagerNet/sing-box/releases/download/v${SB_VER}/sing-box-${SB_VER}-linux-${ARCH}.tar.gz"
    tar -xzf "/tmp/sing-box-${SB_VER}-linux-${ARCH}.tar.gz" -C /tmp; mv /tmp/sing-box-*/sing-box /usr/local/bin/; chmod +x /usr/local/bin/sing-box

    KEYS=$(/usr/local/bin/sing-box generate reality-keypair 2>&1 || true)
    PK=$(echo "$KEYS" | grep -i "Private" | awk '{print $NF}'); PBK=$(echo "$KEYS" | grep -i "Public" | awk '{print $NF}')
    if [[ -z "$PK" ]]; then echo -e "${RED}[!] 核心不兼容 / Core incompatible.${NC}"; exit 1; fi

    UUID=$(uuidgen); SHORT_ID=$(openssl rand -hex 4); SS_PASS=$(openssl rand -base64 16 | tr -d '\n\r')
    HY2_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9'); HY2_OBFS=$(openssl rand -base64 8 | tr -dc 'a-zA-Z0-9')
    
    mkdir -p /etc/sing-box; openssl ecparam -genkey -name prime256v1 -out /etc/sing-box/hy2.key 2>/dev/null
    openssl req -new -x509 -days 36500 -key /etc/sing-box/hy2.key -out /etc/sing-box/hy2.crt -subj "/CN=${REALITY_SNI}" 2>/dev/null

    JSON_VLESS='{ "type": "vless", "listen": "::", "listen_port": '$MAIN_PORT', "tcp_fast_open": true, "users": [{"uuid": "'$UUID'", "flow": "xtls-rprx-vision"}], "tls": { "enabled": true, "server_name": "'$REALITY_SNI'", "reality": { "enabled": true, "handshake": { "server": "'$REALITY_SNI'", "server_port": 443 }, "private_key": "'$PK'", "short_id": ["'$SHORT_ID'"] }, "utls": { "enabled": true, "fingerprint": "chrome" } } }'
    JSON_HY2='{ "type": "hysteria2", "listen": "::", "listen_port": '$MAIN_PORT', "up_mbps": 3000, "down_mbps": 3000, "obfs": { "type": "salamander", "password": "'$HY2_OBFS'" }, "users": [{"password": "'$HY2_PASS'"}], "tls": { "enabled": true, "certificate_path": "/etc/sing-box/hy2.crt", "key_path": "/etc/sing-box/hy2.key" } }'
    JSON_SS='{ "type": "shadowsocks", "listen": "::", "listen_port": '$SS_PORT', "tcp_fast_open": true, "method": "2022-blake3-aes-128-gcm", "password": "'$SS_PASS'" }'

    case $MODE in
        "VLESS") INBOUNDS="[$JSON_VLESS]" ;;
        "HY2") INBOUNDS="[$JSON_HY2]" ;;
        "SS") INBOUNDS="[$JSON_SS]" ;;
        "ALL") INBOUNDS="[$JSON_VLESS, $JSON_HY2, $JSON_SS]" ;;
    esac

    cat > /etc/sing-box/config.json << EOF
{ "log": { "level": "warn" }, "inbounds": $INBOUNDS, "outbounds": [{ "type": "direct" }] }
EOF

    IPT=$(command -v iptables || echo "/sbin/iptables")
    IP6=$(command -v ip6tables || echo "/sbin/ip6tables")

    cat > /etc/systemd/system/sing-box.service << SVC_EOF
[Unit]
After=network.target
[Service]
ExecStartPre=-$IPT -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStartPre=-$IP6 -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStartPre=-$IPT -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStartPre=-$IP6 -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
ExecStopPost=-$IPT -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
ExecStopPost=-$IP6 -t nat -D PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports $MAIN_PORT
Restart=always
LimitNOFILE=1048576
LimitNPROC=infinity
[Install]
WantedBy=multi-user.target
SVC_EOF
    systemctl daemon-reload && systemctl enable --now sing-box; systemctl restart sing-box
    
    sleep 1
    if ! systemctl is-active --quiet sing-box; then
        echo -e "${RED}[!] 致命错误：Sing-box 核心无法启动！ / Fatal Error: Core failed to start!${NC}"
        journalctl -u sing-box --no-pager -n 10; exit 1
    fi

    cat > /etc/ddr/.env << ENV_EOF
CORE="singbox"
MODE="$MODE"
UUID="$UUID"
REALITY_SNI="$REALITY_SNI"
MAIN_PORT="$MAIN_PORT"
SS_PORT="$SS_PORT"
PUBLIC_KEY="$PBK"
SHORT_ID="$SHORT_ID"
HY2_PASS="$HY2_PASS"
HY2_OBFS="$HY2_OBFS"
SS_PASS="$SS_PASS"
LINK_IP="$PUBLIC_IP"
ENV_EOF
    view_config "deploy"
}

# --- [3] 系统维护功能 ---
setup_quota() {
    clear; echo -e "${CYAN}=== 流量监控与自动熔断设置 / Quota Guard ===${NC}"
    read -ep "请输入每月流量熔断上限 (GB，输入 0 取消限制) / Enter quota in GB (0 to disable): " QUOTA_GB
    if [[ "$QUOTA_GB" -gt 0 ]]; then
        cat > /etc/ddr/quota.sh << EOF
#!/bin/bash
TOTAL_TX=\$(vnstat --oneline 2>/dev/null | awk -F';' '{print \$10}' || echo "0")
UNIT=\$(echo \$TOTAL_TX | grep -o '[A-Za-z]*' || echo "KB")
VALUE=\$(echo \$TOTAL_TX | sed 's/[^0-9.]*//g')
VALUE=\${VALUE:-0}
if [[ "\$UNIT" == *"GiB"* ]] || [[ "\$UNIT" == *"GB"* ]] || [[ "\$UNIT" == *"TiB"* ]] || [[ "\$UNIT" == *"TB"* ]]; then
    if [[ "\$UNIT" == *"T"* ]]; then VALUE=\$(echo "\$VALUE * 1024" | bc); fi
    if \$(echo "\$VALUE >= $QUOTA_GB" | bc -l); then
        systemctl stop xray sing-box 2>/dev/null
        echo "Traffic Exceeded: \${VALUE}GB. Services stopped." > /etc/ddr/quota.log
    fi
fi
EOF
        chmod +x /etc/ddr/quota.sh
        (crontab -l 2>/dev/null | grep -v "/etc/ddr/quota.sh"; echo "*/10 * * * * /etc/ddr/quota.sh") | crontab -
        echo -e "${GREEN}✔ 流量熔断已启动，每月超过 ${QUOTA_GB}GB 将触发自动断网保护。 / Quota guard enabled.${NC}"
    else
        crontab -l 2>/dev/null | grep -v "/etc/ddr/quota.sh" | crontab - 2>/dev/null || true
        echo -e "${YELLOW}✔ 流量限制已解除。 / Quota guard disabled.${NC}"
    fi
    read -ep "按回车返回 / Press Enter to return..."
}

diagnostics() {
    clear; echo -e "${CYAN}=== 本机参数与网络诊断测速 / Diagnostics & Speedtest ===${NC}"
    echo -e " ${GREEN}1.${NC} IP 信誉与流媒体解锁检测 (检测 IP 纯净度、欺诈风险及 Netflix/GPT 解锁情况)"
    echo -e " ${GREEN}2.${NC} 全球节点基准测速 (测试 VPS 硬件性能及全球各节点上传/下载带宽)"
    echo -e " ${YELLOW}0.${NC} 返回主菜单"
    echo -e "${BLUE}------------------------------------------------------${NC}"
    read -ep "请选择测速项目 / Please select [0-2]: " diag_choice
    case $diag_choice in
        1) bash <(curl -Ls https://Check.Place) -I ;;
        2) wget -qO- bench.sh | bash ;;
        *) return 0 ;;
    esac
    read -ep "按回车返回 / Press Enter to return..."
}

tune_vps() {
    clear; echo -e "${CYAN}正在执行 VPS 全面优化... / Tuning VPS...${NC}"
    grep -q '1048576' /etc/security/limits.conf || { echo "* soft nofile 1048576" >> /etc/security/limits.conf; echo "* hard nofile 1048576" >> /etc/security/limits.conf; }
    modprobe tcp_bbr 2>/dev/null || true
    cat > /etc/sysctl.d/99-ddr-tune.conf << 'EOF'
fs.file-max = 1048576
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
EOF
    sysctl -p /etc/sysctl.d/99-ddr-tune.conf >/dev/null 2>&1 || true
    echo -e "${GREEN}✔ BBR-Brutal 与高并发限制已解除。 / Tuning complete.${NC}"
    read -ep "按回车返回 / Press Enter to return..."
}

view_config() {
    local CALLER=$1
    clear
    if ! source /etc/ddr/.env 2>/dev/null; then echo -e "${RED}未检测到配置！ / Config not found!${NC}"; sleep 2; return 0; fi
    
    echo -e "${BLUE}======================================================${NC}\n${BOLD}${CYAN}   协议全部节点参数 (${MODE}) / All Protocol Node Parameters ${NC}\n${BLUE}======================================================${NC}"
    echo -e "${BOLD}1. 引擎/Engine:${NC} $CORE | ${BOLD}模式/Mode:${NC} $MODE\n${BOLD}2. UUID:${NC} $UUID\n${BOLD}3. SNI:${NC} $REALITY_SNI\n${BOLD}4. PBK:${NC} $PUBLIC_KEY | ${BOLD}SID:${NC} $SHORT_ID\n${BLUE}------------------------------------------------------${NC}"
    
    if [[ "$MODE" == *"VLESS"* ]] || [[ "$MODE" == *"ALL"* ]]; then
        echo -e "${YELLOW}[ VLESS-Vision 通用链接 / Universal Link ]${NC}\nvless://$UUID@$LINK_IP:$MAIN_PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$REALITY_SNI&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#Aio-VLESS\n"
        echo -e "${PURPLE}[ Clash Meta VLESS YAML ]${NC}\n  - name: Aio-VLESS\n    type: vless\n    server: $LINK_IP\n    port: $MAIN_PORT\n    uuid: $UUID\n    network: tcp\n    tls: true\n    flow: xtls-rprx-vision\n    servername: $REALITY_SNI\n    client-fingerprint: chrome\n    reality-opts:\n      public-key: $PUBLIC_KEY\n      short-id: $SHORT_ID\n"
    fi
    if [[ "$MODE" == *"HY2"* ]] || [[ "$MODE" == *"ALL"* ]]; then
        echo -e "${YELLOW}[ Hysteria 2 通用链接 / Universal Link ]${NC}\nhysteria2://$HY2_PASS@$LINK_IP:$MAIN_PORT/?insecure=1&sni=$REALITY_SNI&alpn=h3&obfs=salamander&obfs-password=$HY2_OBFS&mport=20000-50000#Aio-Hy2\n"
        echo -e "${PURPLE}[ Clash Meta Hysteria2 YAML ]${NC}\n  - name: Aio-Hy2\n    type: hysteria2\n    server: $LINK_IP\n    port: '20000-50000'\n    password: $HY2_PASS\n    alpn: [h3]\n    sni: $REALITY_SNI\n    skip-cert-verify: true\n    obfs: salamander\n    obfs-password: $HY2_OBFS\n"
    fi
    if [[ "$MODE" == *"SS"* ]] || [[ "$MODE" == *"ALL"* ]]; then
        SS_BASE64=$(echo -n "2022-blake3-aes-128-gcm:${SS_PASS}" | base64 -w 0 2>/dev/null || echo -n "2022-blake3-aes-128-gcm:${SS_PASS}" | base64)
        echo -e "${YELLOW}[ Shadowsocks-2022 通用链接 / Universal Link ]${NC}\nss://${SS_BASE64}@${LINK_IP}:$SS_PORT#Aio-SS\n"
        echo -e "${PURPLE}[ Clash Meta SS YAML ]${NC}\n  - name: Aio-SS\n    type: ss\n    server: $LINK_IP\n    port: $SS_PORT\n    cipher: 2022-blake3-aes-128-gcm\n    password: $SS_PASS\n"
    fi
    
    if [[ "$CALLER" == "deploy" ]]; then
        echo -e "${GREEN}✔ 部署成功！如果要查询节点明细再去菜单 13 查看。 / Deployment successful! See Menu 13 later.${NC}"
    fi
    read -ep "按回车返回主菜单 / Press Enter to return..."
}

clean_uninstall() {
    clear; echo -e "${RED}⚠️  卸载交互向导 / Uninstall Wizard${NC}\n 1. 仅删除核心与配置 / Remove core & config only (Keep shortcut)\n 2. 彻底抹除 / Complete purge"
    read -ep " 请选择 / Please select [1-2]: " clean_choice
    systemctl disable --now xray sing-box 2>/dev/null || true
    rm -rf /usr/local/etc/xray /etc/sing-box /usr/local/bin/xray /usr/local/bin/sing-box /etc/systemd/system/xray.service /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    if [[ "$clean_choice" == "2" ]]; then
        crontab -l 2>/dev/null | grep -v "/etc/ddr/quota.sh" | crontab - 2>/dev/null || true
        rm -rf /etc/ddr /usr/local/bin/sb; echo -e "${GREEN}✔ 环境已彻底物理清空。 / Environment completely purged.${NC}"; exit 0
    else
        rm -f /etc/ddr/.env; echo -e "${GREEN}✔ 配置已清理，核心火种保留。 / Configs removed, cache kept.${NC}"; sleep 2
    fi
}

# --- [4] 主控制台循环 ---
setup_shortcut
while true; do
    IPV4=$(curl -s4m3 api.ipify.org || echo "N/A"); PUBLIC_IP="$IPV4"
    systemctl is-active --quiet xray && STATUS="${GREEN}Running (Xray)${NC}" || { systemctl is-active --quiet sing-box && STATUS="${CYAN}Running (Sing-box)${NC}" || STATUS="${RED}Stopped${NC}"; }
    source /etc/ddr/.env 2>/dev/null && CUR_MODE="[${CORE}-${MODE}]" || CUR_MODE=""
    
    clear; echo -e "${BLUE}======================================================${NC}\n${BOLD}${PURPLE}  Aio-box Ultimate Console [Apex V26 Ultimate] ${NC}\n${BLUE}======================================================${NC}"
    echo -e " IP: ${YELLOW}$IPV4${NC} | STATUS: $STATUS $CUR_MODE\n${BLUE}------------------------------------------------------${NC}"
    echo -e " ${YELLOW}--- Xray-core 独立/全家桶安装 | Single/All-in-One ---${NC}\n ${GREEN}1.${NC} 部署 VLESS-Vision (REALITY) / Deploy VLESS\n ${GREEN}2.${NC} 部署 Hysteria 2 / Deploy Hy2\n ${GREEN}3.${NC} 部署 Shadowsocks / Deploy SS-2022\n ${GREEN}4.${NC} 部署 协议全家桶 (三合一) / Deploy All-in-One\n${BLUE}------------------------------------------------------${NC}"
    echo -e " ${CYAN}--- Sing-box  独立/全家桶安装 | Single/All-in-One ---${NC}\n ${GREEN}5.${NC} 部署 VLESS-Vision (REALITY) / Deploy VLESS\n ${GREEN}6.${NC} 部署 Hysteria 2 / Deploy Hy2\n ${GREEN}7.${NC} 部署 Shadowsocks / Deploy SS-2022\n ${GREEN}8.${NC} 部署 协议全家桶 (三合一) / Deploy All-in-One\n${BLUE}------------------------------------------------------${NC}"
    echo -e " ${YELLOW}9.${NC}  流量监控与熔断护卫 / Quota Guard\n ${GREEN}10.${NC} 本机参数与网络诊断测速 / Diagnostics & Speedtest\n ${GREEN}11.${NC} VPS 全面优化 / VPS Tuning\n ${YELLOW}13.${NC} 协议全部节点参数 / All Protocol Node Parameters\n ${YELLOW}14.${NC} 脚本源码 OTA 热更新 / OTA Update\n ${RED}15.${NC} 彻底清空卸载环境 / Clean Uninstall\n ${GREEN}0.${NC}  退出面板 / Exit Dashboard\n${BLUE}======================================================${NC}"
    read -ep " 请选择 / Please select [0-15]: " choice
    case $choice in
        1) deploy_xray "VLESS" ;; 
        2) deploy_xray "HY2" ;; 
        3) deploy_xray "SS" ;; 
        4) deploy_xray "ALL" ;;
        5) deploy_singbox "VLESS" ;; 
        6) deploy_singbox "HY2" ;; 
        7) deploy_singbox "SS" ;; 
        8) deploy_singbox "ALL" ;;
        9) setup_quota ;;
        10) diagnostics ;;
        11) tune_vps ;;
        13) view_config "" ;; 
        14) setup_shortcut "update"; echo -e "OTA 成功。 / OTA Successful."; exit 0 ;;
        15) clean_uninstall ;; 
        0) clear; exit 0 ;; 
        *) sleep 1 ;;
    esac
done
