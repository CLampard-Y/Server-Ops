# Layer 1: System Core

Layer 1 负责服务器系统底座初始化。它运行在 root 权限下，安装和配置必须属于系统层的内容，例如基础 apt 包、Docker Engine、内核参数、Swap、ulimit 和 SSH 安全加固。

Layer 1 不负责业务应用，也不负责用户级开发工具链。Codex、cc-switch-cli、Foundry、Rust、Node/fnm、Python scientific venv、Circom 等内容属于 `layer4_dev_env/`。

## 1. 分层定位

| Layer | 职责 | 典型内容 |
| --- | --- | --- |
| Layer 1 | 系统底座，必须 root 安装 | apt 基础包、Docker Engine、BBR/sysctl、ulimit、Swap、SSH hardening |
| Layer 2 | 长期基础服务 | Portainer、Komari Server、未来反代/数据库/监控服务 |
| Layer 3 | 业务 Docker 应用 | 3x-ui、qBittorrent、Alist、Komari Agent |
| Layer 4 | 用户级开发环境 | Codex、cc-switch-cli、Node/fnm、Foundry、Rust、uv、Python venv、ZK tools |

## 2. 当前目录结构

```text
layer1_system/
  install_core.sh              # Layer 1 主编排脚本
  README.md                    # 当前说明文档
  conf/
    sysctl_optim.conf          # Server-Ops 内核参数模板
  lib/
    common.sh                  # 日志、root 检查、系统版本检查
  modules/
    01_base_packages.sh        # apt update + 基础包安装
    02_timezone_locale.sh      # 时区 + locale
    03_sysctl_bbr.sh           # sysctl + BBR
    04_ulimits.sh              # nofile / systemd limit
    05_docker.sh               # Docker CE + Compose plugin
    06_swap.sh                 # Server-Ops swapfile
    07_ssh_hardening.sh        # GitHub 公钥导入 + SSH hardening
```

## 3. 支持系统

Layer 1 当前支持：

| 系统 | 版本要求 |
| --- | --- |
| Debian | 12+ |
| Ubuntu | 22.04+ |

`install_core.sh` 会在执行前检查系统类型和版本。不支持 CentOS、AlmaLinux、Arch、macOS、WSL 或容器内非完整 systemd 环境。

## 4. 快速使用

推荐从仓库根目录主控脚本执行：

```bash
cd /home/Server-Ops
sudo bash setup.sh
```

只执行 Layer 1：

```bash
sudo GITHUB_USERNAME=<github-user> bash /home/Server-Ops/layer1_system/install_core.sh
```

如果不想配置 SSH hardening，可以不传 `GITHUB_USERNAME`：

```bash
sudo bash /home/Server-Ops/layer1_system/install_core.sh
```

完成后建议重启：

```bash
sudo reboot
```

## 5. 模块说明

| 模块 | 内容 | 主要写入位置 |
| --- | --- | --- |
| `01_base_packages.sh` | 安装系统基础包、编译基础、Python 基础、诊断工具 | apt/dpkg 系统包 |
| `02_timezone_locale.sh` | 设置时区和 `en_US.UTF-8` locale | `/etc/localtime`、locale 配置 |
| `03_sysctl_bbr.sh` | 应用内核参数和 BBR 配置 | `/etc/sysctl.d/99-server-ops-optim.conf` |
| `04_ulimits.sh` | 配置 nofile 与 systemd 默认限制 | `/etc/security/limits.d/`、`/etc/systemd/system.conf.d/` |
| `05_docker.sh` | 安装 Docker CE、Buildx、Compose plugin | `/etc/apt/keyrings/`、`/etc/apt/sources.list.d/docker.list` |
| `06_swap.sh` | 在 Swap 不足时创建 `/swapfile` | `/swapfile`、`/etc/fstab` |
| `07_ssh_hardening.sh` | 导入 GitHub 公钥并配置 SSH hardening | 目标用户 `~/.ssh/authorized_keys`、`/etc/ssh/sshd_config.d/99-server-ops-hardening.conf` |

## 6. 基础包清单

`01_base_packages.sh` 当前安装：

| 类别 | 包 |
| --- | --- |
| 网络工具 | `curl`、`wget`、`net-tools` |
| 开发/版本控制 | `git`、`vim`、`unzip` |
| 编译/构建工具链 | `build-essential`、`pkg-config`、`libssl-dev`、`make`、`cmake`、`clang`、`lld` |
| Python 基础 | `python3`、`python3-pip`、`python3-venv`、`python3-dev` |
| 安全 | `ca-certificates`、`gnupg`、`lsb-release`、`apt-transport-https`、`ufw`、`fail2ban` |
| 监控/诊断 | `htop`、`iotop`、`sysstat`、`tmux` |
| 文件/配置处理 | `jq`、`yq`、`tree`、`ncdu`、`rsync` |

说明：Layer 1 只安装 Python 和编译依赖的系统基础。科学计算包不进入系统 Python，后续由 Layer 4 使用 `uv + venv` 安装。

## 7. APT upgrade 策略

Layer 1 默认执行 `apt-get update`，但不默认执行完整 `apt-get upgrade`，避免远程初始化时意外升级 SSH、OpenSSL、内核或触发服务重启。

如需在初始化时执行完整升级：

```bash
sudo LAYER1_APT_UPGRADE=1 GITHUB_USERNAME=<github-user> \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

## 8. 时区与 Locale

默认时区：

```text
Asia/Shanghai
```

可通过变量覆盖：

```bash
sudo SERVER_OPS_TIMEZONE=Etc/UTC \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

Locale 默认设置为：

```text
LANG=en_US.UTF-8
```

脚本不会持久化设置 `LC_ALL`，避免覆盖系统和应用自身的 locale 策略。

## 9. Sysctl / BBR

配置模板：

```text
layer1_system/conf/sysctl_optim.conf
```

部署目标：

```text
/etc/sysctl.d/99-server-ops-optim.conf
```

脚本会：

- 备份并注释 `/etc/sysctl.conf` 中与 Server-Ops 冲突的核心项。
- 尝试加载 `tcp_bbr`。
- 如果当前内核不支持 BBR，则跳过 `tcp_congestion_control=bbr`，避免整个初始化失败。
- 捕获并打印 `sysctl --system` 错误输出。
- 如果 `sysctl --system` 失败，会恢复 `/etc/sysctl.conf` 和 Server-Ops sysctl drop-in，避免留下半配置状态。

验证：

```bash
sysctl -n net.ipv4.tcp_congestion_control
sysctl -n fs.file-max
```

注意：`sysctl_optim.conf` 包含面向单机服务器的网络参数，例如 `rp_filter=1`。如果服务器承担 VPN、多网卡、策略路由或明显非对称路由，请先审查该配置再应用。

## 10. Docker

Layer 1 使用 Docker 官方源安装：

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
```

脚本会检查 `docker compose version`。如果系统已有 Docker 但缺少 Compose plugin，会尝试补齐 Docker CE 组件。

验证：

```bash
docker --version
docker compose version
systemctl status docker
```

注意：Layer 1 不会默认执行 `usermod -aG docker <user>`，因为 Docker group 基本等价于 root 权限。如确实需要，应单独人工执行并重新登录。

## 11. Swap

Layer 1 的 Swap 策略是“补充而不是接管”：

- 如果当前总 Swap 已达到 2G，则跳过。
- 如果 Swap 不足，则只创建/重建 Server-Ops 自己管理的 `/swapfile`。
- 不关闭、不删除云厂商或系统已有的其他 swap partition/LVM/encrypted swap。
- 修改 `/etc/fstab` 前会创建备份。

验证：

```bash
free -h
swapon --show
grep swap /etc/fstab
```

## 12. SSH hardening

传入 `GITHUB_USERNAME` 后，脚本会从以下地址拉取公钥：

```text
https://github.com/<github-user>.keys
```

目标用户选择规则：

| 场景 | 默认目标用户 |
| --- | --- |
| `sudo bash ...` | `$SUDO_USER` |
| 直接 root 执行 | `root` |
| 手动指定 | `SSH_TARGET_USER=<user>` |

示例：

```bash
sudo SSH_TARGET_USER=ubuntu GITHUB_USERNAME=<github-user> \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

SSH 配置通过 drop-in 管理：

```text
/etc/ssh/sshd_config.d/99-server-ops-hardening.conf
```

默认行为：

```text
PubkeyAuthentication yes
PermitRootLogin prohibit-password
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PasswordAuthentication no
```

如果暂时不想禁用密码登录：

```bash
sudo LAYER1_DISABLE_SSH_PASSWORD_AUTH=0 GITHUB_USERNAME=<github-user> \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

脚本会在 reload/restart SSH 前执行 `sshd -t`，并使用目标用户上下文执行 `sshd -T -C user=<target>` 验证 `PubkeyAuthentication`、`AuthorizedKeysFile` 和密码登录实际生效值。失败时会自动回滚。

重要：执行完 SSH hardening 后，不要立刻关闭当前 SSH 会话。请新开终端测试公钥登录。

## 13. 常用覆盖变量

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `GITHUB_USERNAME` | 空 | GitHub 用户名，用于导入 SSH 公钥；为空则跳过 SSH hardening |
| `SSH_TARGET_USER` | `$SUDO_USER` 或 `root` | SSH 公钥写入目标用户 |
| `LAYER1_DISABLE_SSH_PASSWORD_AUTH` | `1` | 是否禁用 SSH 密码登录 |
| `LAYER1_APT_UPGRADE` | `0` | 是否执行完整 `apt-get upgrade` |
| `SERVER_OPS_TIMEZONE` | `Asia/Shanghai` | 系统时区 |

## 14. 幂等性与重跑说明

Layer 1 可以重复运行，但它是 root 系统层脚本，不是“零副作用”脚本。重复运行时会重新检查系统状态、补齐缺失包、覆盖 Server-Ops managed 配置，并可能产生新的备份文件。

| 模块 | 重跑行为 | 注意事项 |
| --- | --- | --- |
| `01_base_packages.sh` | `apt-get update` 后补齐缺失包；已安装包由 apt 跳过 | 默认不执行 `apt-get upgrade`；如需升级设置 `LAYER1_APT_UPGRADE=1` |
| `02_timezone_locale.sh` | 重新设置时区和 `LANG=en_US.UTF-8` | 旧版本如果写过 `LC_ALL`，新版不会主动清理历史项 |
| `03_sysctl_bbr.sh` | 重新写入 Server-Ops sysctl drop-in，并应用 `sysctl --system` | 失败会回滚配置文件；旧版本已经删除的历史 sysctl 行无法自动恢复 |
| `04_ulimits.sh` | 覆盖 Server-Ops nofile drop-in；PAM 缺少 `pam_limits.so` 时才追加 | PAM 修改前会备份，不会重复追加同一行 |
| `05_docker.sh` | Docker 已存在则检查 Compose plugin；缺失时修复安装 | 已运行容器的机器上重跑仍需谨慎，apt 可能触发 Docker 组件更新 |
| `06_swap.sh` | 当前总 Swap 达到 2G 则跳过；不足时只管理 `/swapfile` | 不会删除其他 swap；旧版本曾删除的 swap 不会自动恢复 |
| `07_ssh_hardening.sh` | GitHub keys 去重写入；SSH drop-in 覆盖为当前标准配置 | 会 reload/restart SSH；重跑时仍需保留当前 SSH 会话并开新终端验证 |

如果之前运行过旧版 Layer 1，再运行新版时需要特别注意：

- 旧版可能把 GitHub keys 写入 `/root/.ssh/authorized_keys`；新版默认写入 `$SUDO_USER` 或 `SSH_TARGET_USER`，不会删除 root 旧 key。
- 旧版可能直接修改过 `/etc/ssh/sshd_config`；新版改用 drop-in，但不会自动清理旧主配置中已经存在的安全参数。
- 旧版可能删除过 `/etc/sysctl.conf` 的冲突行或其他 swap；新版不会凭空恢复已删除的历史配置，只会从当前状态继续安全管理。

建议重跑命令：

```bash
sudo SSH_TARGET_USER=<target-user> GITHUB_USERNAME=<github-user> \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

如需先避免 SSH 密码登录策略变化：

```bash
sudo LAYER1_DISABLE_SSH_PASSWORD_AUTH=0 SSH_TARGET_USER=<target-user> GITHUB_USERNAME=<github-user> \
  bash /home/Server-Ops/layer1_system/install_core.sh
```

## 15. 安全边界

- Layer 1 必须 root 执行。
- Layer 1 会修改系统配置，请优先在新机器或可回滚机器上执行。
- SSH hardening 前请确认 GitHub keys 正确。
- Docker group 授权不默认执行。
- Layer 1 不写 API key，不管理 AI provider，不创建用户级开发工具配置。

## 16. 审计与验证命令

本地语法检查：

```bash
bash -n layer1_system/install_core.sh
bash -n layer1_system/lib/common.sh
for f in layer1_system/modules/[0-9]*.sh; do bash -n "$f"; done
```

目标服务器验证：

```bash
docker --version
docker compose version
sysctl -n net.ipv4.tcp_congestion_control
free -h
swapon --show
sshd -T -C "user=<target-user>,host=$(hostname -f 2>/dev/null || hostname),addr=127.0.0.1" \
  | grep -E '^(passwordauthentication|pubkeyauthentication|authorizedkeysfile|permitrootlogin) '
```
