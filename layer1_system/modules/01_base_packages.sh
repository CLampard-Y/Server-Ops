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
# ===========================================================

run_01_base_packages() {
    step "1/7" "系统更新与基础工具安装"

    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -qq \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold"

    local packages=(
        # 网络工具
        curl wget net-tools
        # 开发/版本控制
        git vim unzip
        # 安全
        ca-certificates gnupg lsb-release
        apt-transport-https
        ufw fail2ban
        # 监控/诊断
        htop iotop sysstat
        # 文件管理
        jq tree ncdu rsync
    )

    apt-get install -y -qq "${packages[@]}" > /dev/null 2>&1
    info "基础工具已安装: ${packages[*]}"
}