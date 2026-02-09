# Server-Ops — 服务器初始化工具

通用基础设施仓库，用于对全新 Linux 服务器进行**分层初始化**。

## 架构概览

```
/home/Server-Ops/          ← 配置源 (Git 仓库)
├── setup.sh               ← 主控脚本 (入口)
├── layer1_system/         ← Layer 1: 系统底层
│   ├── install_core.sh
│   ├── lib/common.sh
│   ├── conf/sysctl_optim.conf
│   └── modules/01~07*.sh
├── layer2_services/       ← Layer 2: 基础容器服务
│   ├── lib/service_common.sh
│   ├── komari/
│   └── portainer/
└── layer3_apps/           ← Layer 3: 业务应用
    ├── deploy_service.sh  ← 万能部署脚本
    ├── s-ui/
    └── alist/

/home/Basic-Ops/           ← Layer 2 运行时目录
├── komari/
└── portainer/

/home/App-Ops/             ← Layer 3 运行时目录
├── s-ui/
└── alist/
```

## 从零开始部署 (全新 Debian 12 / Ubuntu 22.04)

### 第一步: 安装 Git

```bash
apt-get update && apt-get install -y git
```

### 第二步: 克隆仓库到指定路径

```bash
git clone https://github.com/<你的用户名>/Server-Ops.git /home/Server-Ops
```

> ⚠️ **必须克隆到 `/home/Server-Ops`**，脚本内部依赖此路径。

### 第三步: 运行主控脚本

```bash
cd /home/Server-Ops
sudo bash setup.sh
```

脚本会:
1. 询问你的 **GitHub Username** (用于 SSH 公钥免密登录)
2. 显示交互菜单，选择执行范围

### 第四步: 重启生效

```bash
sudo reboot
```

## 分层说明

### Layer 1: System Core (系统底层)

| 模块 | 功能 |
|------|------|
| 01_base_packages | 系统更新 + 基础工具 (htop, ufw, fail2ban, ncdu...) |
| 02_timezone_locale | 时区 Asia/Shanghai + en_US.UTF-8 locale |
| 03_sysctl_bbr | 内核参数优化 + BBR 拥塞控制 |
| 04_ulimits | 文件描述符限制 1048576 |
| 05_docker | Docker CE + Compose 插件 |
| 06_swap | 2G Swap 保险 (防 OOM) |
| 07_ssh_hardening | GitHub 公钥导入 + 禁用密码登录 |

单独执行 Layer 1:

```bash
sudo GITHUB_USERNAME=your-github-id bash /home/Server-Ops/layer1_system/install_core.sh
```

### Layer 2: Basic Services (容器服务)

每个服务独立目录，包含 `docker-compose.yml` + `install.sh`。

| 服务 | 端口 | 说明 |
|------|------|------|
| komari | 3399 | 服务器监控面板 |
| portainer | 9443 | Docker 可视化管理 |

单独安装某个服务:

```bash
sudo bash /home/Server-Ops/layer2_services/komari/install.sh
```

服务运行目录: `/home/Basic-Ops/<服务名>/`

### Layer 3: Business Apps (业务应用)

采用 **Master Deploy Script** 模式，每个应用只需一个 `docker-compose.yml`，无需编写 install.sh。

| 应用 | 端口 | 说明 |
|------|------|------|
| s-ui | host模式 | Xray 面板 |
| alist | 5244 | 文件列表/网盘聚合 |

部署方式:

```bash
# 交互式菜单
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh

# 直接部署指定应用
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh s-ui

# 查看状态
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh --status
```

服务运行目录: `/home/App-Ops/<应用名>/`

## 添加新服务

### Layer 2 (基础服务)

```bash
mkdir -p /home/Server-Ops/layer2_services/新服务名/
vim /home/Server-Ops/layer2_services/新服务名/docker-compose.yml
cp /home/Server-Ops/layer2_services/komari/install.sh \
   /home/Server-Ops/layer2_services/新服务名/install.sh
# 编辑 install.sh，将 deploy_service "komari" 改为 deploy_service "新服务名"
```

### Layer 3 (业务应用) — 更简单

```bash
# 只需两步：创建目录 + 放入 docker-compose.yml
mkdir -p /home/Server-Ops/layer3_apps/新应用名/
vim /home/Server-Ops/layer3_apps/新应用名/docker-compose.yml

# 无需编写任何脚本，deploy_service.sh 自动发现并部署
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh 新应用名
```

## 目录约定

| 路径 | 用途 |
|------|------|
| `/home/Server-Ops/` | 配置源 (仓库代码，只读参考) |
| `/home/Basic-Ops/` | Layer 2 运行时 (基础容器服务) |
| `/home/App-Ops/` | Layer 3 运行时 (业务应用) |

## 许可证

MIT