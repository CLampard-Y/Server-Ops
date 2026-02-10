#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — 主控脚本
#  执行方式: sudo bash /home/Server-Ops/setup.sh
#
#  功能:
#    - 交互式菜单，统一调度 Layer 1 / Layer 2 / Layer 3
#    - 首次运行时引导用户输入 GitHub Username
#    - 支持单独执行某一层或某个服务
# ===========================================================
set -euo pipefail

# ── 路径常量 ──
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER1_DIR="${REPO_DIR}/layer1_system"
LAYER2_DIR="${REPO_DIR}/layer2_services"
LAYER3_DIR="${REPO_DIR}/layer3_apps"
BASIC_OPS_HOME="/home/Basic-Ops"
APP_OPS_HOME="/home/App-Ops"

# ── 颜色常量 ──
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ── 日志函数 ──
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# ── 前置检查 ──
if [[ $EUID -ne 0 ]]; then
    error "请使用 root 权限运行: sudo bash $0"
fi

# ===========================================================
#  GitHub Username 交互获取
# ===========================================================
ask_github_username() {
    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│${NC}  ${BOLD}SSH 免密登录配置${NC}"
    echo -e "${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  输入你的 GitHub Username，脚本将自动拉取公钥"
    echo -e "${CYAN}│${NC}  并禁用密码登录，实现安全的 SSH 免密认证。"
    echo -e "${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  公钥来源: https://github.com/<username>.keys"
    echo -e "${CYAN}│${NC}"
    echo -e "${CYAN}│${NC}  ${YELLOW}留空则跳过 SSH 加固${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────┘${NC}"
    echo ""
    read -rp "GitHub Username: " GITHUB_USERNAME
    export GITHUB_USERNAME

    if [[ -n "${GITHUB_USERNAME}" ]]; then
        info "将使用 GitHub 用户 [${GITHUB_USERNAME}] 的公钥"
    else
        warn "已跳过 SSH 加固，后续可手动配置"
    fi
}

# ===========================================================
#  Layer 1: System Core
# ===========================================================
run_layer1() {
    local script="${LAYER1_DIR}/install_core.sh"
    if [[ -f "${script}" ]]; then
        chmod +x "${script}"
        bash "${script}"
    else
        error "找不到 ${script}，请确认仓库结构完整"
    fi
}

# ===========================================================
#  Layer 2: 服务发现 + 安装
# ===========================================================
discover_services() {
    local services=()
    for dir in "${LAYER2_DIR}"/*/; do
        [[ -d "${dir}" && -f "${dir}/install.sh" ]] || continue
        local name
        name=$(basename "${dir}")
        [[ "${name}" == "lib" ]] && continue
        services+=("${name}")
    done
    echo "${services[@]}"
}

install_single_service() {
    local service_name="$1"
    local script="${LAYER2_DIR}/${service_name}/install.sh"
    if [[ -f "${script}" ]]; then
        chmod +x "${script}"
        bash "${script}"
    else
        error "找不到 ${script}"
    fi
}

install_all_services() {
    local services
    read -ra services <<< "$(discover_services)"
    if [[ ${#services[@]} -eq 0 ]]; then
        warn "未发现任何可安装的服务"
        return 0
    fi
    for svc in "${services[@]}"; do
        install_single_service "${svc}"
    done
}

show_service_menu() {
    local services
    read -ra services <<< "$(discover_services)"

    if [[ ${#services[@]} -eq 0 ]]; then
        warn "未发现任何可安装的服务"
        return 0
    fi

    echo ""
    echo -e "${CYAN}  可用服务列表:${NC}"
    echo ""
    local i=1
    for svc in "${services[@]}"; do
        local status="未部署"
        [[ -d "${BASIC_OPS_HOME}/${svc}" ]] && status="${GREEN}已部署${NC}"
        printf "    ${BOLD}%d)${NC}  %-20s [%b]\n" "${i}" "${svc}" "${status}"
        ((i++))
    done
    echo ""
    printf "    ${BOLD}A)${NC}  安装全部服务\n"
    printf "    ${BOLD}0)${NC}  返回主菜单\n"
    echo ""

    read -rp "  请选择 [0-${#services[@]}/A]: " choice

    if [[ "${choice}" == "0" ]]; then
        return 0
    elif [[ "${choice}" =~ ^[Aa]$ ]]; then
        install_all_services
    elif [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#services[@]} )); then
        install_single_service "${services[$((choice - 1))]}"
    else
        warn "无效选择"
    fi
}

# ===========================================================
#  Layer 3: Business Apps (委托给 deploy_service.sh)
# ===========================================================
run_layer3() {
    local script="${LAYER3_DIR}/deploy_service.sh"
    if [[ -f "${script}" ]]; then
        chmod +x "${script}"
        bash "${script}"
    else
        error "找不到 ${script}，请确认仓库结构完整"
    fi
}

# ===========================================================
#  系统状态概览
# ===========================================================
show_status() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}系统状态概览${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"

    # Docker
    local docker_ver="未安装"
    if command -v docker &>/dev/null; then
        docker_ver=$(docker --version 2>/dev/null | sed -n 's/.*version \([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
    fi
    printf "${CYAN}║${NC}  %-14s %-38s${CYAN}║${NC}\n" "Docker:" "${docker_ver}"

    # Compose
    local compose_ver="未安装"
    docker compose version &>/dev/null && compose_ver=$(docker compose version --short 2>/dev/null)
    printf "${CYAN}║${NC}  %-14s %-38s${CYAN}║${NC}\n" "Compose:" "${compose_ver}"

    # BBR
    local bbr_val
    bbr_val=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    printf "${CYAN}║${NC}  %-14s %-38s${CYAN}║${NC}\n" "BBR:" "${bbr_val}"

    # Timezone
    local tz_val
    tz_val=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")
    printf "${CYAN}║${NC}  %-14s %-38s${CYAN}║${NC}\n" "时区:" "${tz_val}"

    # SSH Keys
    local key_count=0
    [[ -f /root/.ssh/authorized_keys ]] && key_count=$(grep -c '^ssh-' /root/.ssh/authorized_keys 2>/dev/null || echo 0)
    printf "${CYAN}║${NC}  %-14s %-38s${CYAN}║${NC}\n" "SSH 公钥:" "${key_count} 个"

    # Swap
    local swap_val
    swap_val=$(free -h | awk '/Swap/{print $2}')
    printf "${CYAN}║${NC}  %-14s %-38s${CYAN}║${NC}\n" "Swap:" "${swap_val}"

    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"

    # Layer 2 已部署的服务
    echo -e "${CYAN}║${NC}  ${BOLD}Layer 2 基础服务 (${BASIC_OPS_HOME}):${NC}"
    _show_deployed_services "${BASIC_OPS_HOME}"

    # Layer 3 已部署的应用
    echo -e "${CYAN}║${NC}  ${BOLD}Layer 3 业务应用 (${APP_OPS_HOME}):${NC}"
    _show_deployed_services "${APP_OPS_HOME}"

    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 辅助: 显示某个目录下已部署的服务
_show_deployed_services() {
    local base_dir="$1"
    if [[ -d "${base_dir}" ]]; then
        local found=0
        for svc_dir in "${base_dir}"/*/; do
            [[ -d "${svc_dir}" ]] || continue
            local svc_name
            svc_name=$(basename "${svc_dir}")
            local running="停止"
            if [[ -f "${svc_dir}/docker-compose.yml" ]]; then
                (cd "${svc_dir}" && docker compose ps --format '{{.Status}}' 2>/dev/null) | grep -qi 'up' && running="${GREEN}运行中${NC}"
            fi
            printf "${CYAN}║${NC}    %-18s [%b]\n" "${svc_name}" "${running}"
            ((found++))
        done
        [[ ${found} -eq 0 ]] && echo -e "${CYAN}║${NC}    (无)"
    else
        echo -e "${CYAN}║${NC}    (无)"
    fi
}

# ===========================================================
#  主菜单
# ===========================================================
show_main_menu() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Server-Ops — 服务器初始化工具${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}1)${NC}  Layer 1: 系统底层初始化                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        (Docker, BBR, Sysctl, SSH 加固...)            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}2)${NC}  Layer 2: 基础容器服务                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        (Komari, Portainer...)                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}3)${NC}  Layer 3: 业务应用部署                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        (S-UI, Alist...)                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}A)${NC}  一键全部执行 (Layer 1 + 2 + 3)              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}S)${NC}  查看系统状态                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}    ${BOLD}0)${NC}  退出                                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ===========================================================
#  入口
# ===========================================================
main() {
    # 首次运行: 询问 GitHub Username
    ask_github_username

    while true; do
        show_main_menu
        read -rp "  请选择 [0-3/A/S]: " choice

        case "${choice}" in
            1)
                run_layer1
                ;;
            2)
                show_service_menu
                ;;
            3)
                run_layer3
                ;;
            [Aa])
                info "开始一键全部执行..."
                run_layer1
                echo ""
                info "Layer 1 完成，继续安装 Layer 2 服务..."
                echo ""
                install_all_services
                echo ""
                info "Layer 2 完成，继续部署 Layer 3 应用..."
                echo ""
                run_layer3
                echo ""
                info "全部完成！建议重启: sudo reboot"
                break
                ;;
            [Ss])
                show_status
                ;;
            0)
                info "再见！"
                exit 0
                ;;
            *)
                warn "无效选择，请重试"
                ;;
        esac
    done
}

main