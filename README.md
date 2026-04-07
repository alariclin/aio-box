# Sing-box & Xray DDR Master Console

- 感谢 [Xray-core](https://github.com/XTLS/Xray-core) 与 [Sing-box](https://github.com/SagerNet/sing-box) 提供的强大开源核心引擎支持。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Core: Dual](https://img.shields.io/badge/Core-Xray%20%7C%20Sing--box-blue)]()
[![Language: Bilingual](https://img.shields.io/badge/Language-%E4%B8%AD%E6%96%87%20%7C%20English-green)]()
[![OS: Linux](https://img.shields.io/badge/OS-Debian%20%7C%20Ubuntu%20%7C%20CentOS-orange)]()

**DDR (Deep Deterministic Reasoning) Ultimate Console** 是一款专为极端网络环境打造的“双核·全量级”一键防弹部署脚本。它不仅提供最前沿的代理协议，还囊括了 VPS 极致开荒、流量熔断保护与 2D SNI 自动感知矩阵。

## ✨ 核心功能

* **双核自适应驱动:** 完美支持 Xray-core (含最新 xhttp 架构) 与 Sing-box，一键自由切换。
* **全维协议矩阵:** 一键部署 VLESS-Reality、Hysteria 2 (Salamander 熵混淆)、Shadowsocks 2022。
* **VPS 极致开荒:** 内置极客级调优，一键自动注入 Swap 虚拟内存、解除 Ulimit 物理并发限制、爆改 TCP 网络栈与 BBR。
* **流量熔断守卫:** 基于内核 API (`10085` 端口) 的极速流量查账。支持设定月度流量阈值，超额自动断网防止云服务器天价账单。
* **2D 智能 SNI 嗅探:** 自动探测 VPS 所在机房 (ASN) 与国家，为你动态匹配最符合物理归属的伪装目标 (如 AWS/GCP/Azure 等真实域名)。
* **全自动防弹衣:** 自动探测端口冲突清场僵尸进程、针对 RHEL/CentOS 自动放行 SELinux、100% 免疫系统时钟误差握手失败。
* **易于管理:** 拥有中英双语交互式面板，支持多用户动态增删与加密链接 (URI) 一键提取。

## 🚀 快速开始

### 1. 安装 / 升级核心

在你的 VPS 终端 (Root 用户) 执行以下命令即可拉取最新脚本并进入交互式安装界面：

```bash
bash <(curl -Ls [https://raw.githubusercontent.com/alariclin/sing-box-auto-ddr/main/install.sh](https://raw.githubusercontent.com/alariclin/sing-box-auto-ddr/main/install.sh))
