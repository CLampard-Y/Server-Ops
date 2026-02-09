#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — Layer 3: 万能服务部署脚本 (Master Deploy Script)
#
#  用法:
#    sudo bash deploy_service.sh <服务名>    # 直接部署指定服务
#    sudo bash deploy_service.sh             # 交互式选择菜单
#    sudo bash deploy_service.sh --list      # 列出所有可用服务
#    sudo bash deploy_service.sh --status    # 查看所有服务状态
#
#  设计理念:
#    每个服务文件夹只需包含 docker-compose.yml (及可选的 .env, configs/)
#    无需编写任何 install.sh，本脚本统一处理部署逻辑
#
#  源目录: /home/Server-Ops/layer3_apps/<服务名>/
#  目标目录: /home/App-Ops/<服务名>/
# ===========================================================
set -euo pipefail

# ── 路径常量 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_OPS_HOME="/home/App-Ops"

# ── 颜色常量 ──
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# ── 日志函数 ──
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
die()   { err "$*"; exit 1; }

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}$1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ── 前置检查 ──
preflight() {
    [[ $EUID -ne 0 ]] && die "请使用 root 权限运行: sudo bash $0"

    if ! command -v docker &>/dev/null; then
        die "Docker 未安装！请先执行 Layer 1 初始化:\n  sudo bash /home/Server-Ops/layer1_system/install_core.sh"
    fi

    if ! docker compose version &>/dev/null; then
        die "Docker Compose 插件未安装！请先执行 Layer 1 初始化"
    fi
}

# ===========================================================
#  服务发现: 扫描当前目录下所有包含 docker-compose.yml 的文件夹
# ===========================================================
discover_services() {
    local services=()
    for dir in "${SCRIPT_DIR}"/*/; do
        [[ ! -d "${dir}" ]] && continue
        local name
        name=$(basename "${dir}")
        [[ "${name}" == .* ]] && continue
        [[ -f "${dir}/docker-compose.yml" ]] || continue
        services+=("${name}")
    done
    printf '%s\n' "${services[@]}" | sort
}

# ===========================================================
#  获取服务运行状态
# ===========================================================
get_service_status() {
    local service_name="$1"
    local target_dir="${APP_OPS_HOME}/${service_name}"

    if [[ ! -d "${target_dir}" ]]; then
        echo "未部署"
        return
    fi

    if [[ ! -f "${target_dir}/docker-compose.yml" ]]; then
        echo "目录存在但缺少配置"
        return
    fi

    local running
    running=$(cd "${target_dir}" && docker compose ps --format '{{.Status}}' 2>/dev/null | grep -ci 'up' || echo "0")

    if [[ "${running}" -gt 0 ]]; then
        echo -e "${GREEN}运行中${NC} (${running} 容器)"
    else
        echo -e "${YELLOW}已停止${NC}"
    fi
}

# ===========================================================
#  文件同步 (rsync 优先，cp 回退)
# ===========================================================
sync_files() {
    local src="$1"
    local dst="$2"

    if command -v rsync &>/dev/null; then
        rsync -av --delete \
            --exclude='.git' \
            --exclude='.gitkeep' \
            --exclude='README.md' \
            "${src}/" "${dst}/"
        info "文件已通过 rsync 同步"
    else
        find "${dst}" -mindepth 1 -maxdepth 1 \
            ! -name '.env' \
            -exec rm -rf {} + 2>/dev/null || true
        cp -rv "${src}/"* "${dst}/" 2>/dev/null || true
        cp -v "${src}"/.[!.]* "${dst}/" 2>/dev/null || true
        info "文件已通过 cp 同步"
    fi
}

# ===========================================================
#  部署单个服务
# ===========================================================
deploy_service() {
    local service_name="$1"
    local source_dir="${SCRIPT_DIR}/${service_name}"
    local target_dir="${APP_OPS_HOME}/${service_name}"

    banner "部署服务: ${service_name}"

    # ── Check: 验证源目录 ──
    if [[ ! -d "${source_dir}" ]]; then
        die "服务目录不存在: ${source_dir}"
    fi

    if [[ ! -f "${source_dir}/docker-compose.yml" ]]; then
        die "缺少 docker-compose.yml: ${source_dir}/"
    fi

    info "源目录验证通过: ${source_dir}"

    # ── 覆盖保护 ──
    if [[ -d "${target_dir}" ]]; then
        warn "目标目录已存在: ${target_dir}"

        local running=0
        if [[ -f "${target_dir}/docker-compose.yml" ]]; then
            running=$(cd "${target_dir}" && docker compose ps --format '{{.Status}}' 2>/dev/null | grep -ci 'up' || echo "0")
        fi

        if [[ "${running}" -gt 0 ]]; then
            warn "检测到 ${running} 个运行中的容器"
            echo ""
            echo -e "  ${BOLD}选择操作:${NC}"
            echo "    1) 停止旧容器并重新部署 (推荐)"
            echo "    2) 仅更新配置文件，不重启容器"
            echo "    3) 取消"
            echo ""
            read -rp "  请选择 [1-3]: " action
            case "${action}" in
                1)
                    info "停止旧容器..."
                    cd "${target_dir}" && docker compose down --remove-orphans 2>/dev/null || true
                    ;;
                2)
                    warn "仅同步配置，不重启容器"
                    sync_files "${source_dir}" "${target_dir}"
                    info "配置已更新: ${target_dir}"
                    info "如需生效请手动: cd ${target_dir} && docker compose up -d"
                    return 0
                    ;;
                *)
                    warn "已取消部署 ${service_name}"
                    return 0
                    ;;
            esac
        else
            read -rp "是否覆盖？(y/N): " confirm
            if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
                warn "已取消部署 ${service_name}"
                return 0
            fi
        fi
    fi

    # ── Target: 创建目标目录 ──
    mkdir -p "${target_dir}"
    info "目标目录已就绪: ${target_dir}"

    # ── Sync: 同步文件 ──
    sync_files "${source_dir}" "${target_dir}"

    # ── Deploy: 启动服务 ──
    cd "${target_dir}"
    info "正在启动 ${service_name}..."
    docker compose up -d

    # ── Output: 验证并输出结果 ──
    sleep 3
    local status
    status=$(get_service_status "${service_name}")

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}✅ Service ${service_name} deployed successfully${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  目标目录: ${target_dir}"
    echo -e "${GREEN}║${NC}  运行状态: ${status}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  查看日志: cd ${target_dir} && docker compose logs -f"
    echo -e "${GREEN}║${NC}  停止服务: cd ${target_dir} && docker compose down"
    echo -e "${GREEN}║${NC}  重启服务: cd ${target_dir} && docker compose restart"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ===========================================================
#  交互式选择菜单
# ===========================================================
show_select_menu() {
    local services=()
    while IFS= read -r svc; do
        [[ -n "${svc}" ]] && services+=("${svc}")
    done < <(discover_services)

    if [[ ${#services[@]} -eq 0 ]]; then
        die "未发现任何可部署的服务 (需要包含 docker-compose.yml 的子目录)"
    fi

    banner "Layer 3: 应用服务部署"

    echo -e "  ${BOLD}可用服务:${NC}"
    echo ""

    local i=1
    for svc in "${services[@]}"; do
        local status
        status=$(get_service_status "${svc}")
        printf "    ${BOLD}%2d)${NC}  %-22s [%b]\n" "${i}" "${svc}" "${status}"
        ((i++))
    done

    echo ""
    printf "    ${BOLD} A)${NC}  部署全部服务\n"
    printf "    ${BOLD} 0)${NC}  退出\n"
    echo ""

    read -rp "  请选择 [0-${#services[@]}/A]: " choice

    if [[ "${choice}" == "0" ]]; then
        info "再见！"
        exit 0
    elif [[ "${choice}" =~ ^[Aa]$ ]]; then
        echo ""
        warn "即将部署全部 ${#services[@]} 个服务"
        read -rp "确认？(y/N): " confirm
        [[ "${confirm}" != "y" && "${confirm}" != "Y" ]] && { warn "已取消"; exit 0; }
        for svc in "${services[@]}"; do
            deploy_service "${svc}"
        done
    elif [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#services[@]} )); then
        deploy_service "${services[$((choice - 1))]}"
    else
        die "无效选择: ${choice}"
    fi
}

# ===========================================================
#  --list: 列出所有可用服务
# ===========================================================
cmd_list() {
    local services=()
    while IFS= read -r svc; do
        [[ -n "${svc}" ]] && services+=("${svc}")
    done < <(discover_services)

    if [[ ${#services[@]} -eq 0 ]]; then
        warn "未发现任何可部署的服务"
        return
    fi

    echo ""
    echo -e "  ${BOLD}可用服务 (${#services[@]}):${NC}"
    echo ""
    for svc in "${services[@]}"; do
        local has_env=" "
        local has_conf=" "
        [[ -f "${SCRIPT_DIR}/${svc}/.env" ]] && has_env="E"
        [[ -d "${SCRIPT_DIR}/${svc}/configs" ]] && has_conf="C"
        printf "    %-22s [%s%s] %s\n" "${svc}" "${has_env}" "${has_conf}" \
            "$(echo -e "${DIM}${SCRIPT_DIR}/${svc}/${NC}")"
    done
    echo ""
    echo -e "  ${DIM}标记: E=含.env  C=含configs/${NC}"
    echo ""
}

# ===========================================================
#  --status: 查看所有服务状态
# ===========================================================
cmd_status() {
    local services=()
    while IFS= read -r svc; do
        [[ -n "${svc}" ]] && services+=("${svc}")
    done < <(discover_services)

    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Layer 3: 服务状态总览${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"

    for svc in "${services[@]}"; do
        local status
        status=$(get_service_status "${svc}")
        printf "${CYAN}║${NC}    %-22s %b\n" "${svc}" "${status}"
    done

    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ===========================================================
#  入口
# ===========================================================
main() {
    preflight

    case "${1:-}" in
        --list|-l)
            cmd_list
            ;;
        --status|-s)
            cmd_status
            ;;
        --help|-h)
            echo "用法: sudo bash $0 [服务名|选项]"
            echo ""
            echo "参数:"
            echo "  <服务名>       直接部署指定服务"
            echo "  (无参数)       交互式选择菜单"
            echo "  --list,  -l    列出所有可用服务"
            echo "  --status,-s    查看所有服务运行状态"
            echo "  --help,  -h    显示此帮助"
            echo ""
            ;;
        "")
            show_select_menu
            ;;
        *)
            deploy_service "$1"
            ;;
    esac
}

main "$@"