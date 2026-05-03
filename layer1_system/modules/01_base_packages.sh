#!/usr/bin/env bash
# ===========================================================
#  Module 01: 系统更新 + 基础工具安装
#  调用方式: 由 install_core.sh source 加载
#
#  新增/拓展说明 (相比原 PT 脚本):
#    - ufw:    宿主机防火墙，生产服务器必备
#    - ncdu:   磁盘空间交互式分析，排查空间问题
#    - tree:   目录结构可视化，调试部署结构
#    - rsync:  高效文件同步，备份/迁移必备
#    - fail2ban: 自动封禁暴力破解 IP
#    - apt-transport-https: 安全源传输
#    - build-essential/pkg-config/libssl-dev: Rust/Halo2/原生依赖编译基础
#    - make/cmake/clang/lld: Solidity/ZK 项目常用构建工具链
#    - python3-venv/python3-dev: Layer 4 uv/科学计算 venv 基础
#    - tmux: 远程开发与长任务会话管理
#    - yq: YAML/Compose 配置检查与自动化处理
#    - bubblewrap: Codex/Linux sandbox 系统依赖
# ===========================================================

run_01_base_packages() {
    step "1/7" "系统更新与基础工具安装"

    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    local apt_log
    apt_log="$(mktemp)"

    if ! apt-get update -qq > "${apt_log}" 2>&1; then
        warn "APT update 失败，输出如下:"
        while IFS= read -r line; do
            echo "  ${line}" >&2
        done < "${apt_log}"
        rm -f "${apt_log}"
        error "APT update 失败"
    fi

    if [[ "${LAYER1_APT_UPGRADE:-0}" == "1" ]]; then
        if ! apt-get upgrade -y -qq \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            > "${apt_log}" 2>&1; then
            warn "APT upgrade 失败，输出如下:"
            while IFS= read -r line; do
                echo "  ${line}" >&2
            done < "${apt_log}"
            rm -f "${apt_log}"
            error "APT upgrade 失败"
        fi
    else
        info "跳过 apt-get upgrade；如需启用请设置 LAYER1_APT_UPGRADE=1"
    fi

    local packages=(
        # 网络工具
        curl wget net-tools
        # 开发/版本控制
        git vim unzip
        # 编译/构建工具链
        build-essential pkg-config libssl-dev
        make cmake clang lld
        # Python 基础运行环境 (科学包放 Layer 4 venv，不污染系统 Python)
        python3 python3-pip python3-venv python3-dev
        # 安全
        ca-certificates gnupg lsb-release
        apt-transport-https
        ufw fail2ban bubblewrap
        # 监控/诊断
        htop iotop sysstat tmux
        # 文件管理
        jq yq tree ncdu rsync
    )

    local unavailable=()
    local package
    for package in "${packages[@]}"; do
        if dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -q "install ok installed"; then
            continue
        fi

        if ! apt-cache show "${package}" > /dev/null 2>&1; then
            unavailable+=("${package}")
        fi
    done

    if (( ${#unavailable[@]} > 0 )); then
        rm -f "${apt_log}"
        error "APT 源中找不到且尚未安装以下基础包: ${unavailable[*]}"
    fi

    if ! apt-get install -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        "${packages[@]}" > "${apt_log}" 2>&1; then
        warn "基础包安装失败，APT 输出如下:"
        while IFS= read -r line; do
            echo "  ${line}" >&2
        done < "${apt_log}"
        rm -f "${apt_log}"
        error "基础包安装失败"
    fi

    rm -f "${apt_log}"

    local missing=()
    for package in "${packages[@]}"; do
        if ! dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -q "install ok installed"; then
            missing+=("${package}")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        error "以下基础包安装后校验失败: ${missing[*]}"
    fi

    info "基础工具已安装: ${packages[*]}"
}
