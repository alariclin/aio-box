# All-in-One Duo

- [English Version Description](documents/en/README_EN.md)
- 感谢 [Xray-core](https://github.com/XTLS/Xray-core) 与 [Sing-box](https://github.com/SagerNet/sing-box) 提供的强大核心支持。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/alariclin/all-in-one-duo?style=flat&color=yellow)](https://github.com/alariclin/all-in-one-duo/stargazers)
[![English Version](https://img.shields.io/badge/English-Version-blue)](documents/en/README_EN.md)
[![Telegram Group](https://img.shields.io/badge/Telegram-Group-blue)](https://t.me/your_telegram_link)

**All-in-One Duo** 是一款专为 2026 年极端网络环境打造的“双核·全矩阵”一键防弹部署脚本。
它深度集成了 **Xray-core (xhttp)** 与 **Sing-box (全能矩阵)**，并提供极客级 VPS 开荒调优与内核级流量熔断机制。

## ✨ 核心功能
* **双核自适应:** 完美调度 Xray 与 Sing-box。支持全家桶部署或单协议拆分部署。
* **VPS 极致开荒:** 一键注入 Swap、破除 Ulimit 限制、爆改 TCP 网络栈与 BBR 调优。
* **流量熔断守卫:** 毫秒级查账，支持设定月度限额 (Quota)，超额自动物理断网。
* **2D SNI 矩阵:** 自动探测机房 ASN 与位置，匹配最真实的伪装域名 (AWS/GCP/Azure 等)。
* **防弹衣架构:** 自动清场僵尸端口、SELinux 自动放行、强制时钟对齐。

## 🚀 快速开始

### 1. 安装与部署 (Root 用户)
```bash
bash <(curl -Ls [https://raw.githubusercontent.com/alariclin/all-in-one-duo/main/install.sh](https://raw.githubusercontent.com/alariclin/all-in-one-duo/main/install.sh))
