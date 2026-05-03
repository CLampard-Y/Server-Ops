#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — Layer 1: System Core 主编排脚本
#  适用系统: Debian 12 / Ubuntu 22.04+
#  执行方式: sudo bash /home/Server-Ops/layer1_system/install_core.sh
#
#  功能: 按顺序加载并执行 modules/ 下的所有模块
#    01 系统更新 + 基础工具
#    02 时区 + Locale 标准化
#    03 内核参数 + BBR
#    04 文件描述符限制
#    05 Docker + Compose
#    06 Swap 保险
#    07 SSH 安全加固
# ===========================================================
set -euo pipefail

# ── 定位自身路径 ──
LAYER1_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LAYER1_DIR

# ── 加载公共函数库 ──
source "${LAYER1_DIR}/lib/common.sh"

# ── 前置检查 ──
require_root
require_debian_like

# ── 接收外部参数 ──
export GITHUB_USERNAME="${GITHUB_USERNAME:-}"

banner "Server-Ops — Layer 1: System Core 初始化"
echo "  脚本路径: ${LAYER1_DIR}"
echo "  操作系统: $(. /etc/os-release && echo "${PRETTY_NAME}")"
echo "  当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
[[ -n "${GITHUB_USERNAME}" ]] && echo "  GitHub:    ${GITHUB_USERNAME}"
echo ""

# ── 按顺序加载所有模块 ──
for module in "${LAYER1_DIR}"/modules/[0-9]*.sh; do
    if [[ -f "${module}" ]]; then
        source "${module}"
    else
        warn "未找到模块文件: ${module}"
    fi
done

# ── 按顺序执行所有模块 ──
run_01_base_packages
run_02_timezone_locale
run_03_sysctl_bbr
run_04_ulimits
run_05_docker
run_06_swap
run_07_ssh_hardening

# ── 完成报告 ──
ssh_report_user="${SSH_TARGET_USER:-${SUDO_USER:-root}}"
ssh_report_home="$(getent passwd "${ssh_report_user}" 2>/dev/null | cut -d: -f6 || true)"
ssh_key_count="0"
if [[ -n "${ssh_report_home}" && -f "${ssh_report_home}/.ssh/authorized_keys" ]]; then
    ssh_key_count="$(grep -cE '^(ssh-|ecdsa-|sk-)' "${ssh_report_home}/.ssh/authorized_keys" 2>/dev/null || true)"
    ssh_key_count="${ssh_key_count:-0}"
fi

echo ""
echo -e "${C_CYAN}╔══════════════════════════════════════════════════════╗${C_NC}"
echo -e "${C_CYAN}║${C_NC}  ${C_BOLD}✅  Layer 1: System Core 初始化完成!${C_NC}"
echo -e "${C_CYAN}╠══════════════════════════════════════════════════════╣${C_NC}"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "BBR:"     "$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "Docker:"  "$(docker --version 2>/dev/null | sed -n 's/.*version \([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "Compose:" "$(docker compose version --short 2>/dev/null)"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "时区:"    "$(timedatectl show --property=Timezone --value)"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "Locale:"  "$(locale 2>/dev/null | grep LANG= | head -1)"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "Swap:"    "$(free -h | awk '/Swap/{print $2}')"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "file-max:" "$(sysctl -n fs.file-max)"
printf "${C_CYAN}║${C_NC}  %-14s %-38s${C_CYAN}║${C_NC}\n" "SSH:"     "${ssh_report_user}: ${ssh_key_count} 个公钥"
echo -e "${C_CYAN}╠══════════════════════════════════════════════════════╣${C_NC}"
echo -e "${C_CYAN}║${C_NC}  ⚠️  建议重启一次使所有内核参数完全生效:          ${C_CYAN}║${C_NC}"
echo -e "${C_CYAN}║${C_NC}     sudo reboot                                    ${C_CYAN}║${C_NC}"
echo -e "${C_CYAN}╚══════════════════════════════════════════════════════╝${C_NC}"
echo ""
