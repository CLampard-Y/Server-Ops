# Layer 4: Dev Environment

Layer 4 用来把服务器配置成“用户级开发环境”。它和 Layer 1/2/3 分开管理，避免把 AI coding、Solidity、Rust、Python、ZK 工具链混进系统层或业务 Docker 应用层。

## 1. 分层定位

| Layer | 职责 | 典型内容 |
| --- | --- | --- |
| Layer 1 | 系统底座，必须 root 安装 | Docker Engine、BBR、SSH、Swap、ulimit、基础 apt 包、编译依赖 |
| Layer 2 | 长期基础服务 | Portainer、Komari Server、未来反代/数据库/监控服务 |
| Layer 3 | 业务 Docker 应用 | 3x-ui、qBittorrent、Alist、Komari Agent |
| Layer 4 | 用户级开发环境 | Codex、cc-switch-cli、Node/fnm、Foundry、Rust、uv、Python venv、ZK 工具、远程计算 helper |

Layer 4 默认由 VS Code Remote-SSH 使用的开发用户执行，工具安装到 `$HOME`，不写入 `/usr/local`，也不写入任何 API key。

## 2. 当前目录结构

```text
layer4_dev_env/
  install_dev_env.sh          # Layer 4 主安装器
  README.md                   # 当前说明文档
  lib/
    common.sh                 # 日志、路径、安全检查、npm HOME prefix 检查
  profiles/
    hk-dev.sh                 # HK 主开发机 profile
    us-compute.sh             # US 重计算 runner profile
    minimal.sh                # JP/跳板机最小 profile
  modules/
    01_user_dirs.sh           # 创建用户目录与私有配置目录
    02_shell_profile.sh       # 写入 ~/.bashrc managed PATH block
    03_node_fnm.sh            # 用户级 fnm + Node.js
    04_ai_coding_tools.sh     # Codex CLI
    05_cc_switch_cli.sh       # cc-switch-cli
    06_foundry.sh             # Foundry / forge / cast / anvil
    07_rust.sh                # rustup + stable toolchain
    08_python_uv.sh           # uv + MoonMath/scientific Python venv
    09_zk_tools.sh            # Circom + circomlib + snarkjs，默认关闭
    10_remote_compute.sh      # HK -> US 同步与 forge test helper
  templates/
    AGENTS.md                 # 项目 agent 指南模板
    foundry.gitignore         # Foundry 项目 .gitignore 模板
```

## 3. Profiles

| Profile | 适用机器 | 默认安装 | 默认不安装 |
| --- | --- | --- | --- |
| `hk-dev` | HK 主开发机 | 用户目录、PATH、Node/fnm、Codex、cc-switch-cli、Foundry、Rust、uv、Python scientific venv、US helper | ZK tools |
| `us-compute` | US Dedicated 计算 runner | 用户目录、PATH、Node/fnm、Foundry、Rust、uv、Python scientific venv | Codex、cc-switch-cli、ZK tools、US helper |
| `minimal` | JP 跳板/极简环境 | 用户目录、PATH | AI tools、Foundry、Rust、Node、Python venv、ZK tools |

## 4. 快速使用

### HK 主开发机

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
source ~/.bashrc
```

HK profile 适合日常 Solidity、ZK 学习、AI coding、轻量测试和把任务分发到 US 机器。

### US 重计算 runner

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-compute
source ~/.bashrc
```

US profile 默认不安装 Codex/cc-switch-cli，也不写 API/provider 配置。它主要用于 fuzz test、ZK proving、benchmark 等重任务。

如果确实需要在 US 临时启用 AI 工具，可以显式打开：

```bash
INSTALL_CODEX_CLI=1 INSTALL_CC_SWITCH_CLI=1 \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh us-compute
```

### JP 跳板/最小环境

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh minimal
source ~/.bashrc
```

JP 不建议安装 AI tools、API key、ZK proving 工具链，只保留最小 shell 与目录结构。

## 5. 模块内容说明

| 模块 | 内容 | 安装位置/数据位置 |
| --- | --- | --- |
| `01_user_dirs.sh` | 创建代码目录和私有配置目录 | `~/code/*`、`~/.config`、`~/.codex`、`~/.cc-switch` |
| `02_shell_profile.sh` | 管理 Layer 4 PATH | `~/.bashrc` managed block |
| `03_node_fnm.sh` | 安装 fnm 与 Node.js | `~/.local/share/fnm` |
| `04_ai_coding_tools.sh` | 安装 Codex CLI | 用户级 npm global prefix |
| `05_cc_switch_cli.sh` | 安装 cc-switch-cli | `~/.local/bin`、`~/.cc-switch` |
| `06_foundry.sh` | 安装 Foundry | `~/.foundry/bin` |
| `07_rust.sh` | 安装 Rust stable | `~/.cargo`、`~/.rustup` |
| `08_python_uv.sh` | 安装 uv，并创建科学计算 venv | `~/.local/bin/uv`、默认 `~/code/.venvs/moonmath` |
| `09_zk_tools.sh` | 安装 Circom、circomlib、snarkjs | `~/.cargo/bin`、用户级 npm global prefix |
| `10_remote_compute.sh` | 安装 HK -> US helper | `~/.local/bin` |

## 6. Python 科学计算环境

`08_python_uv.sh` 会安装 `uv`，并默认创建：

```text
~/code/.venvs/moonmath
```

该 venv 要求系统 `python3 >= 3.10`。Layer 1 已安装 `python3`、`python3-venv`、`python3-dev`，用于支撑这里的用户级 venv。

默认安装的科学计算包使用固定版本，保证 HK/US 多次安装结果一致：

```text
numpy==2.2.6
sympy==1.13.3
matplotlib==3.10.0
pandas==2.2.3
ipython==8.31.0
```

使用方式：

```bash
source ~/code/.venvs/moonmath/bin/activate
python -c "import sympy; print(sympy.__version__)"
ipython
```

如需自定义 venv 路径：

```bash
PYTHON_SCIENCE_VENV_DIR=~/code/.venvs/zk-math \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
```

如需自定义包列表：

```bash
PYTHON_SCIENCE_PACKAGES="numpy==2.2.6 sympy==1.13.3 pandas==2.2.3" \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
```

注意：科学计算包不安装到系统 Python，不使用全局 `pip3 install`，避免污染 Layer 1。

## 7. ZK 工具链

ZK 工具链版本敏感，因此 `hk-dev` 和 `us-compute` 默认都不安装 ZK tools：

```bash
INSTALL_ZK_TOOLS=0
```

需要 Circom 课程或电路练习时再显式安装：

```bash
INSTALL_ZK_TOOLS=1 \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
```

当前 `09_zk_tools.sh` 安装：

| 工具 | 安装方式 | 说明 |
| --- | --- | --- |
| `circom` | 默认 pin 到 Git tag `v2.2.3` | 安装到 `~/.cargo/bin` |
| `circomlib` | 默认安装 `circomlib@2.0.5` | 用户级 npm global package |
| `snarkjs` | 默认安装 `snarkjs@0.7.6` | 用户级 npm global command |

验证：

```bash
circom --version
snarkjs --version
npm list -g --depth=0 circomlib
```

Circom 项目中引用 circomlib 时，推荐项目内安装，保证项目可复现：

```bash
npm install --save-dev circomlib@2.0.5
```

如果临时使用全局 circomlib，可以给 `circom` 指定 npm 全局库路径：

```bash
circom -l "$(npm root -g)" circuit.circom
```

适用于以下 include 形式：

```circom
include "circomlib/circuits/poseidon.circom";
```

Layer 4 常用健康检查：

```bash
uv --version
source ~/code/.venvs/moonmath/bin/activate
python -c "import numpy, sympy, pandas; print('python science ok')"
circom --version
snarkjs --version
npm list -g --depth=0 circomlib
```

如需 pin Circom commit：

```bash
INSTALL_ZK_TOOLS=1 CIRCOM_GIT_REF_TYPE=rev CIRCOM_GIT_REF=<commit-sha> \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
```

如需改用其他 tag：

```bash
INSTALL_ZK_TOOLS=1 CIRCOM_GIT_REF_TYPE=tag CIRCOM_GIT_REF=v2.2.2 \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
```

Noir、Barretenberg/BB、Risc0、SP1 暂未默认接入，后续按学习阶段单独做 optional modules 并 pin 版本。

## 8. Codex + cc-switch-cli

HK profile 默认安装 Codex CLI 和 cc-switch-cli，但不会写入任何 provider 或 API key。

安装后在目标用户账号下执行：

```bash
cc-switch env tools
cc-switch --app codex provider add
cc-switch --app codex provider list
cc-switch --app codex provider switch <id>
codex --help
```

API key 只应通过目标机器上的 `cc-switch` 写入用户目录，不要提交到本仓库。

相关目录：

```text
~/.cc-switch
~/.codex
~/.config/opencode
```

这些目录会以 `700` 权限创建。

## 9. 代码目录

Layer 4 会创建：

```text
~/code/solidity
~/code/zk
~/code/practice
~/code/audits
~/code/research
~/code/benchmarks
```

建议用法：

| 目录 | 用途 |
| --- | --- |
| `~/code/solidity` | Foundry/Solidity 主线项目 |
| `~/code/zk` | Circom、MoonMath、ZK 练习 |
| `~/code/practice` | 课程练习、小实验 |
| `~/code/audits` | 审计练习和报告 |
| `~/code/research` | 长期研究材料 |
| `~/code/benchmarks` | fuzz/proving/benchmark 工作区 |

## 10. HK -> US 远程计算 helper

HK profile 默认安装：

```text
~/.local/bin/server-ops-sync-to-us
~/.local/bin/server-ops-us-forge-test
```

示例：

```bash
server-ops-sync-to-us ~/code/solidity/my-project cc_US:~/code/solidity/my-project
server-ops-us-forge-test ~/code/solidity/my-project --fuzz-runs 100000 -vvv
```

前提：本机 SSH config 已有 `cc_US`。

`server-ops-sync-to-us` 默认不删除远端文件。需要镜像删除时显式启用：

```bash
SERVER_OPS_RSYNC_DELETE=1 \
  server-ops-sync-to-us ~/code/solidity/my-project cc_US:~/code/solidity/my-project
```

同步 helper 会排除常见 secret 文件，例如 `.env`、`.npmrc`、`.ssh`、key/token/mnemonic/keystore 等，但项目特定 secret 仍需自行检查。

## 11. 常用覆盖变量

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `NODE_VERSION` | `22` | fnm 安装的 Node.js 版本 |
| `INSTALL_CODEX_CLI` | HK 为 `1`，US/Minimal 为 `0` | 是否安装 Codex CLI |
| `INSTALL_CC_SWITCH_CLI` | HK 为 `1`，US/Minimal 为 `0` | 是否安装 cc-switch-cli |
| `INSTALL_ZK_TOOLS` | `0` | 是否安装 Circom/circomlib/snarkjs |
| `PYTHON_SCIENCE_VENV_DIR` | `~/code/.venvs/moonmath` | Python scientific venv 路径 |
| `PYTHON_SCIENCE_PACKAGES` | 固定版本科学计算包 | Python scientific venv 包列表 |
| `CIRCOM_GIT_URL` | `https://github.com/iden3/circom.git` | Circom Git 源 |
| `CIRCOM_GIT_REF_TYPE` | `tag` | Circom Git ref 类型，支持 `tag`/`rev`/`branch` |
| `CIRCOM_GIT_REF` | `v2.2.3` | Circom Git ref |
| `CIRCOM_GIT_REV` | 空 | 兼容旧变量；设置后会作为 `CIRCOM_GIT_REF` 使用 |
| `CIRCOMLIB_VERSION` | `2.0.5` | circomlib npm 版本 |
| `SNARKJS_VERSION` | `0.7.6` | snarkjs npm 版本 |
| `CARGO_HOME` | `~/.cargo` | Cargo home，必须解析到 `$HOME` 下 |
| `CARGO_INSTALL_ROOT` | `$CARGO_HOME` | `cargo install --root` 目标，必须解析到 `$HOME` 下 |
| `INSTALL_ZK_FORCE` | `0` | 设置为 `1` 时强制重装 pinned Circom |
| `ALLOW_LAYER4_ROOT` | `0` | 是否允许 root 执行 Layer 4 |

## 12. 幂等性与重跑说明

Layer 4 比 Layer 1 更适合重复运行。它默认写入 `$HOME`，不会写 `/usr/local`，不会写 API key，也不会删除已有 provider 配置。

| 模块 | 重跑行为 | 注意事项 |
| --- | --- | --- |
| `01_user_dirs.sh` | 已有目录会保留，缺失目录会补齐 | `~/.config`、`~/.codex`、`~/.cc-switch` 使用私有权限 |
| `02_shell_profile.sh` | 替换 `.bashrc` 中的 managed block，不重复追加 PATH | 每次修改前会生成 `.bashrc.bak.*` 备份 |
| `03_node_fnm.sh` | 复用已有 fnm/Node，缺失时补装 | Node 版本由 `NODE_VERSION` 控制，默认 `22` |
| `04_ai_coding_tools.sh` | 用户级 `codex` 已存在则跳过；非用户级安装会警告 | npm global prefix 必须在 `$HOME` 下 |
| `05_cc_switch_cli.sh` | 复用/补齐 `cc-switch-cli` 和 `~/.cc-switch` | 不创建 provider，不写 API key，不删除已有 provider |
| `06_foundry.sh` | 复用 Foundry，并通过 `foundryup` 校验/更新 | Foundry upstream 版本会随时间变化，不是严格 pin |
| `07_rust.sh` | 复用 rustup/cargo，并确保 stable toolchain | stable toolchain 可能随时间更新 |
| `08_python_uv.sh` | 复用 existing venv，并把科学包校准到固定版本 | 默认 venv 是 `~/code/.venvs/moonmath`；不会污染系统 Python |
| `09_zk_tools.sh` | 默认不运行；启用后校准 Circom/circomlib/snarkjs 版本 | `circom` 版本不匹配会报错，需 `INSTALL_ZK_FORCE=1` 强制重装 |
| `10_remote_compute.sh` | 覆盖写入 helper 脚本到 `~/.local/bin` | 不会主动同步项目，只有手动调用 helper 才会操作远端 |

如果之前运行过旧版 Layer 4，再运行新版通常会发生：

- 旧版只安装了 `uv` 时，新版会补齐 `~/code/.venvs/moonmath` 和固定版本科学计算包。
- 旧版只安装了 `snarkjs` 时，只有显式 `INSTALL_ZK_TOOLS=1` 才会补齐 Circom/circomlib，并校准 snarkjs 版本。
- 旧版 `.bashrc` managed block 会被新版 managed block 替换，不会重复堆叠 PATH。
- 旧版或手动创建的 `~/.cc-switch`、`~/.codex`、provider/API 配置不会被删除或覆盖。

推荐重跑 HK profile：

```bash
bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
source ~/.bashrc
```

如需安装或校准 ZK tools：

```bash
INSTALL_ZK_TOOLS=1 bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
source ~/.bashrc
```

如果已存在的 `circom` 版本不符合默认 pin，需要明确强制重装：

```bash
INSTALL_ZK_TOOLS=1 INSTALL_ZK_FORCE=1 \
  bash /home/Server-Ops/layer4_dev_env/install_dev_env.sh hk-dev
```

## 13. 安全规则

- Layer 4 默认禁止 root 执行；如果明确要安装到 `/root`，必须设置 `ALLOW_LAYER4_ROOT=1`。
- npm global prefix 必须在 `$HOME` 下，否则安装 AI/ZK npm 工具时会失败，避免污染系统目录。
- 不写入 API key、不创建 cc-switch provider、不提交任何 provider 配置。
- `~/.cc-switch`、`~/.codex`、`~/.config/opencode` 使用 `700` 权限。
- 不要在 JP 跳板机执行 `hk-dev` profile。
- US 默认保持 compute runner，不默认放 AI tools 和 API key。

## 14. 暂未接入的内容

| 内容 | 状态 | 建议 |
| --- | --- | --- |
| OpenCode CLI | 未安装 | 如果确认服务器上需要直接使用，再加入 Layer 4 optional switch |
| Halo2 具体工具 | 未全局安装 | 优先由具体 Rust 项目的 `Cargo.toml` 管理 |
| Noir / BB / Risc0 / SP1 | 未安装 | 后续按学习阶段单独加 optional modules |
| GitHub CLI `gh` | 未安装 | 可选，不急 |
