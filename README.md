# All-in-One Duo

- 致敬开源：感谢 [Xray-core](https://github.com/XTLS/Xray-core) 与 [Sing-box](https://github.com/SagerNet/sing-box) 提供的强大核心引擎。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/alariclin/all-in-one-duo?style=flat&color=yellow)](https://github.com/alariclin/all-in-one-duo/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/alariclin/all-in-one-duo?style=flat&color=orange)](https://github.com/alariclin/all-in-one-duo/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/alariclin/all-in-one-duo?style=flat&color=red)](https://github.com/alariclin/all-in-one-duo/issues)

**All-in-One Duo** 是一款专为 2026 年极端网络审查环境打造的“双核·全矩阵”一键防弹部署脚本。
它彻底摒弃了臃肿的旧协议，将底层逻辑聚焦于 **Xray-core (xhttp)** 与 **Sing-box (全能矩阵)** 的双核无缝切换，并集成了极客级 VPS 开荒调优与内核级流量熔断机制。

## ✨ 核心功能 (Features)

* **双核自适应驱动:** 完美调度 Xray-core 与 Sing-box。支持“全家桶”组合部署，或单协议乐高式独立部署。
* **前沿协议矩阵:** 原生集成 VLESS-Reality (Vision / xhttp)、Hysteria 2 (Salamander 熵混淆)、Shadowsocks 2022。
* **VPS 极致开荒:** 内置极客级服务器调优。支持一键注入 Swap 虚拟内存、破除 Ulimit 物理并发限制、爆改 TCP 网络栈与 BBR 拥塞控制算法。
* **内核级流量守卫:** 基于底层 API 的极速流量查账。支持设定月度流量阈值 (Quota)，超额自动物理断网，彻底告别云服务器天价账单。
* **2D 智能 SNI 矩阵:** 自动探测 VPS 机房 (ASN) 与地理位置，动态推演并匹配最符合物理归属的不可证伪伪装目标 (如 AWS/GCP/Azure 等)。
* **多层防弹衣:** 战前僵尸端口清场、针对 RHEL/CentOS 的 SELinux 自动放行、强制时钟对齐免疫握手失败。

## 🚀 快速开始 (Quick Start)

### 1. 安装与部署

在你的 VPS 终端 (Root 用户环境) 执行以下命令，即可零时差拉取最新核心并进入中英双语交互式面板：

```bash
bash <(curl -Ls [https://raw.githubusercontent.com/alariclin/all-in-one-duo/main/install.sh](https://raw.githubusercontent.com/alariclin/all-in-one-duo/main/install.sh))
