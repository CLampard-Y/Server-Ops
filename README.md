# Server-Ops — 服务器初始化与分层运维工具

Server-Ops 用于把全新 Debian/Ubuntu 服务器按层初始化为可复用、可审计、低污染的运行环境。

当前仓库按四层组织：

| Layer | 名称 | 职责 | 执行权限 |
| --- | --- | --- | --- |
| Layer 1 | System Core | 系统底座：apt 基础包、Docker、BBR/sysctl、ulimit、Swap、SSH hardening | root |
| Layer 2 | Basic Services | 长期基础服务：Portainer、Komari Server 等 | root / Docker |
| Layer 3 | Business Apps | 业务 Docker 应用：3x-ui、qBittorrent、Alist、subconverter、Komari Agent 等 | root / Docker |
| Layer 4 | Dev Environment | 用户级开发环境：Codex、cc-switch-cli、Foundry、Rust、Node/fnm、uv、ZK tools | 开发用户 |

## 1. 仓库结构

```text
/home/Server-Ops/                  # 配置源 Git 仓库
  setup.sh                         # root 主控菜单，调度 Layer 1/2/3
  README.md                        # 仓库总说明
  .gitattributes                   # Bash 脚本保持 LF
  layer1_system/                   # Layer 1: 系统底座
    install_core.sh
    README.md
    conf/sysctl_optim.conf
    lib/common.sh
    modules/01~07*.sh
  layer2_services/                 # Layer 2: 基础长期服务
    lib/service_common.sh
    komari/
    portainer/
  layer3_apps/                     # Layer 3: 业务 Docker 应用
    deploy_service.sh
    3x-ui/
    alist/
    komari-agent/
    qbittorrent/
    s-ui/
    subconverter/
  layer4_dev_env/                  # Layer 4: 用户级开发环境
    install_dev_env.sh
    README.md
    profiles/
    modules/
    templates/

/home/Basic-Ops/                   # Layer 2 运行时目录
/home/App-Ops/                     # Layer 3 运行时目录
~/code/                            # Layer 4 用户代码目录
```

## 2. 从零开始部署

适用系统：Debian 12+ / Ubuntu 22.04+

### 2.1 安装 Git

```bash
apt-get update && apt-get install -y git
```

### 2.2 克隆仓库

```bash
git clone https://github.com/<你的用户名>/Server-Ops.git /home/Server-Ops
```

推荐使用 `/home/Server-Ops` 作为固定路径，便于脚本、文档和远程维护保持一致。

### 2.3 执行 root 主控脚本

```bash
cd /home/Server-Ops
sudo bash setup.sh
```

主控脚本会：

1. 询问 GitHub Username，用于 Layer 1 SSH 公钥导入。
2. 显示 Layer 1/2/3 菜单。
3. 支持单独执行某层或一键执行 Layer 1 + 2 + 3。

完成 Layer 1 后建议重启：

```bash
sudo reboot
```

### 2.4 执行用户级 Layer 4

Layer 4 不通过 root 主控菜单执行。请使用 VS Code Remote-SSH 的开发用户登录后运行：

US primary development host：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-dev
source ~/.bashrc
```

HK fallback/auxiliary 开发机：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
source ~/.bashrc
```

未来 compute-only runner：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-compute
source ~/.bashrc
```

JP 跳板/最小环境：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh minimal
source ~/.bashrc
```

## 3. Layer 1: System Core

详细说明见：`layer1_system/README.md`

Layer 1 负责 root 级系统初始化。

| 模块 | 功能 |
| --- | --- |
| `01_base_packages` | `apt-get update` + 基础包安装；默认不执行完整 `apt-get upgrade` |
| `02_timezone_locale` | 时区与 `en_US.UTF-8` locale |
| `03_sysctl_bbr` | 内核参数、BBR、file-max、TCP 参数 |
| `04_ulimits` | nofile 与 systemd 默认限制 |
| `05_docker` | Docker CE + Buildx + Compose plugin |
| `06_swap` | Swap 不足时补充 Server-Ops `/swapfile` |
| `07_ssh_hardening` | GitHub 公钥导入 + SSH drop-in hardening |

Layer 1 审计后已强化回滚与验证逻辑：sysctl 应用失败会回滚配置；SSH hardening 会按目标用户上下文验证有效配置后再 reload/restart SSH；基础包中包含 `bubblewrap`，用于支持 Codex/Linux sandbox。

单独执行：

```bash
sudo GITHUB_USERNAME=<github-user> bash /home/Server-Ops/layer1_system/install_core.sh
```

常用覆盖变量：

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `GITHUB_USERNAME` | 空 | 导入 GitHub SSH 公钥；为空则跳过 SSH hardening |
| `SSH_TARGET_USER` | `$SUDO_USER` 或 `root` | 公钥写入目标用户 |
| `LAYER1_DISABLE_SSH_PASSWORD_AUTH` | `1` | 是否禁用 SSH 密码登录 |
| `LAYER1_APT_UPGRADE` | `0` | 是否执行完整 `apt-get upgrade` |
| `SERVER_OPS_TIMEZONE` | `Asia/Shanghai` | 系统时区 |

## 4. Layer 2: Basic Services

Layer 2 用于长期运行的基础服务。每个服务独立目录，通常包含 `docker-compose.yml` 和 `install.sh`。

| 服务 | 默认端口 | 说明 |
| --- | --- | --- |
| `komari` | `3399` | 服务器监控面板 |
| `portainer` | `9443` | Docker 可视化管理 |

单独安装某个服务：

```bash
sudo bash /home/Server-Ops/layer2_services/komari/install.sh
```

运行时目录：

```text
/home/Basic-Ops/<service>/
```

## 5. Layer 3: Business Apps

Layer 3 使用统一部署脚本 `deploy_service.sh`。每个应用只需要提供自己的 `docker-compose.yml`，部署脚本会自动发现。

| 应用 | 说明 |
| --- | --- |
| `3x-ui` | Xray 面板 |
| `s-ui` | Xray 面板/兼容旧目录 |
| `alist` | 文件列表/网盘聚合 |
| `qbittorrent` | BT 下载服务 |
| `subconverter` | 订阅转换服务 |
| `komari-agent` | Komari Agent |

交互式部署：

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh
```

部署指定应用：

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh 3x-ui
```

查看状态：

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh --status
```

运行时目录：

```text
/home/App-Ops/<app>/
```

注意：`deploy_service.sh` 会同步应用配置到 `/home/App-Ops/<app>/`。运行时数据应放到 `/home/App-Data/<app>/` 或应用自己的数据目录，避免被配置同步覆盖。

## 6. Layer 4: Dev Environment

详细说明见：`layer4_dev_env/README.md`

Layer 4 是用户级开发环境，不应 root 执行，不写 API key，不污染 `/usr/local`。

| Profile | 适用机器 | 默认内容 |
| --- | --- | --- |
| `us-dev` | US dedicated 主开发机与 Codex host | Node/fnm、Codex、cc-switch-cli、Foundry、Rust、uv、Python scientific venv |
| `hk-dev` | HK fallback/auxiliary 开发机 | Node/fnm、Codex、cc-switch-cli、Foundry、Rust、uv、Python scientific venv、US helper |
| `us-compute` | 未来 compute-only runner | Node/fnm、Foundry、Rust、uv、Python scientific venv；AI tools 默认关闭 |
| `minimal` | JP 跳板/极简环境 | 用户目录与 PATH block |

当前 topology：US dedicated server 是 primary Solidity development host 和 Codex host；HK 保留为 fallback/auxiliary development host；`us-compute` 保留给未来的 compute-only runner。

US 主开发机：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-dev
source ~/.bashrc
```

ZK tools 默认关闭。需要 Circom/circomlib/snarkjs 时显式启用：

```bash
INSTALL_ZK_TOOLS=1 bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-dev
```

## 7. 添加新服务或应用

### 7.1 添加 Layer 2 基础服务

```bash
mkdir -p /home/Server-Ops/layer2_services/<service>/
vim /home/Server-Ops/layer2_services/<service>/docker-compose.yml
cp /home/Server-Ops/layer2_services/komari/install.sh \
   /home/Server-Ops/layer2_services/<service>/install.sh
```

编辑 `install.sh`，将服务名改为新服务名。

### 7.2 添加 Layer 3 业务应用

```bash
mkdir -p /home/Server-Ops/layer3_apps/<app>/
vim /home/Server-Ops/layer3_apps/<app>/docker-compose.yml
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh <app>
```

### 7.3 添加 Layer 4 开发工具

Layer 4 新工具应遵循：

- 安装到 `$HOME` 下。
- 不写 API key。
- 不污染 `/usr/local`。
- 通过 profile 开关控制不同 development、compute 和 minimal 角色是否启用。
- 版本敏感工具应 pin 版本或提供明确覆盖变量。

## 8. 目录约定

| 路径 | 用途 |
| --- | --- |
| `/home/Server-Ops/` | 配置源 Git 仓库 |
| `/home/Basic-Ops/` | Layer 2 运行时目录 |
| `/home/App-Ops/` | Layer 3 Compose 配置运行目录 |
| `/home/App-Data/` | 建议的 Layer 3 应用数据目录 |
| `~/code/` | Layer 4 用户代码工作区 |
| `~/.local/bin` | Layer 4 用户级命令 |
| `~/.cc-switch`、`~/.codex`、`~/.config/opencode` | Layer 4 AI/provider 用户配置目录 |

## 9. 幂等性与重跑说明

Layer 1 和 Layer 4 都按“可重复运行”设计，但含义不同：

| 层 | 幂等性结论 | 重跑说明 |
| --- | --- | --- |
| Layer 1 | 基本幂等，但会修改系统配置 | 会补齐缺失 apt 包、覆盖 Server-Ops managed 配置、生成备份、reload SSH/Docker 等系统服务 |
| Layer 4 | 幂等性更强 | 主要写入 `$HOME`；已有工具复用，managed `.bashrc` block 替换，Python/ZK 包校准到固定版本 |

如果之前运行过旧版 Layer 1，新版可以重跑，但不会自动恢复旧版已经删除的历史配置，例如旧 sysctl 行或曾被旧 swap 逻辑移除的 swap 设备。重跑 Layer 1 时建议保持当前 SSH 会话，并使用第二个终端验证登录。

推荐 Layer 1 重跑方式：

```bash
sudo SSH_TARGET_USER=<target-user> GITHUB_USERNAME=<github-user> \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

推荐 Layer 4 重跑方式：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-dev
source ~/.bashrc
```

如需补齐或校准 ZK tools：

```bash
INSTALL_ZK_TOOLS=1 bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-dev
```

更详细的幂等性说明见：

- `layer1_system/README.md`
- `layer4_dev_env/README.md`

## 10. 验证命令

Layer 1：

```bash
docker --version
docker compose version
sysctl -n net.ipv4.tcp_congestion_control
free -h
swapon --show
sshd -T -C "user=<target-user>,host=$(hostname -f 2>/dev/null || hostname),addr=127.0.0.1" \
  | grep -E '^(passwordauthentication|pubkeyauthentication|authorizedkeysfile|permitrootlogin) '
```

Layer 4：

```bash
node --version
forge --version
rustc --version
uv --version
source ~/code/.venvs/moonmath/bin/activate
python -c "import numpy, sympy, pandas; print('python science ok')"
```

如果安装了 ZK tools：

```bash
circom --version
snarkjs --version
npm list -g --depth=0 circomlib
```

## 11. 安全原则

- Layer 1 才能 root 执行；Layer 4 默认禁止 root 执行。
- 仓库不保存 API key、provider secrets、钱包私钥、助记词或 `.env`。
- SSH hardening 后不要立即关闭当前 SSH 会话，应新开终端测试登录。
- Docker group 授权不默认执行，因为它接近 root 权限。
- US dedicated server 使用 `us-dev`，作为 primary Solidity development host 和 Codex host。
- HK 使用 `hk-dev`，作为 fallback/auxiliary development host。
- `us-compute` 保留给未来的 compute-only runner，默认不安装 AI tools。
- JP 机器默认作为跳板/最小环境，不运行完整 dev profile。

## 12. 许可证

MIT
