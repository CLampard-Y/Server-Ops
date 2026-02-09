#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — Layer 2: 服务安装公共函数库
#  所有服务的 install.sh 通过 source 加载此文件
#
#  提供:
#    - 统一的日志/颜色函数
#    - deploy_service()  通用部署流程
#    - remove_service()  通用卸载流程
# ===========================================================

# ── 颜色常量 ──
readonly SVC_RED='\033[0;31m'
readonly SVC_GREEN='\033[0;32m'
readonly SVC_YELLOW='\033[1;33m'
readonly SVC_CYAN='\033[0;36m'
readonly SVC_BOLD='\033[1m'
readonly SVC_NC='\033[0m'

# ── 日志函数 ──
svc_info()  { echo -e "${SVC_GREEN}[✓]${SVC_NC} $*"; }
svc_warn()  { echo -e "${SVC_YELLOW}[!]${SVC_NC} $*"; }
svc_error() { echo -e "${SVC_RED}[✗]${SVC_NC} $*"; exit 1; }

svc_banner() {
    echo ""
    echo -e "${SVC_CYAN}╔══════════════════════════════════════════════════╗${SVC_NC}"
    echo -e "${SVC_CYAN}║${SVC_NC}  ${SVC_BOLD}$1${SVC_NC}"
    echo -e "${SVC_CYAN}╚══════════════════════════════════════════════════╝${SVC_NC}"
    echo ""
}

# ── 常量 ──
readonly BASIC_OPS_HOME="/home/Basic-Ops"

# ── 前置检查 ──
svc_require_root() {
    [[ $EUID -ne 0 ]] && svc_error "请使用 root 权限运行: sudo bash $0"
}

svc_require_docker() {
    if ! command -v docker &> /dev/null; then
        svc_error "Docker 未安装，请先执行 Layer 1 初始化"
    fi
    if ! docker compose version &> /dev/null; then
        svc_error "Docker Compose 插件未安装，请先执行 Layer 1 初始化"
    fi
}

# ===========================================================
#  deploy_service — 通用服务部署函数
#
#  参数:
#    $1  服务名称 (如 "komari")
#    $2  源目录   (包含 docker-compose.yml 的目录)
#
#  流程:
#    1. 创建目标目录 /home/Basic-Ops/<服务名>/
#    2. 复制 docker-compose.yml 到目标目录
#    3. 复制 .env (如果存在)
#    4. 进入目标目录执行 docker compose up -d
# ===========================================================
deploy_service() {
    local service_name="$1"
    local source_dir="$2"
    local target_dir="${BASIC_OPS_HOME}/${service_name}"

    svc_banner "部署服务: ${service_name}"

    # ── 验证源文件 ──
    if [[ ! -f "${source_dir}/docker-compose.yml" ]]; then
        svc_error "找不到 ${source_dir}/docker-compose.yml"
    fi

    # ── 创建目标目录 ──
    if [[ -d "${target_dir}" ]]; then
        svc_warn "目标目录已存在: ${target_dir}"
        read -rp "是否覆盖？(y/N): " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            svc_warn "已取消部署 ${service_name}"
            return 0
        fi
    fi

    mkdir -p "${target_dir}"
    svc_info "目标目录已就绪: ${target_dir}"

    # ── 复制编排文件 ──
    cp -v "${source_dir}/docker-compose.yml" "${target_dir}/"
    svc_info "docker-compose.yml 已复制"

    # ── 复制 .env (如果存在) ──
    if [[ -f "${source_dir}/.env" ]]; then
        cp -v "${source_dir}/.env" "${target_dir}/"
        svc_info ".env 配置已复制"
    fi

    # ── 复制额外配置文件 (如果存在 conf/ 目录) ──
    if [[ -d "${source_dir}/conf" ]]; then
        cp -rv "${source_dir}/conf" "${target_dir}/"
        svc_info "conf/ 配置目录已复制"
    fi

    # ── 启动服务 ──
    cd "${target_dir}"
    svc_info "正在启动 ${service_name}..."
    docker compose up -d

    # ── 验证 ──
    sleep 3
    if docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null | grep -qi "up"; then
        svc_info "${service_name} 启动成功 ✓"
        docker compose ps
    else
        svc_warn "${service_name} 可能未正常启动，请检查日志:"
        svc_warn "  cd ${target_dir} && docker compose logs"
    fi

    echo ""
    svc_info "服务目录: ${target_dir}"
    svc_info "查看日志: cd ${target_dir} && docker compose logs -f"
    svc_info "停止服务: cd ${target_dir} && docker compose down"
    echo ""
}

# ===========================================================
#  remove_service — 通用服务卸载函数
#
#  参数:
#    $1  服务名称 (如 "komari")
# ===========================================================
remove_service() {
    local service_name="$1"
    local target_dir="${BASIC_OPS_HOME}/${service_name}"

    svc_banner "卸载服务: ${service_name}"

    if [[ ! -d "${target_dir}" ]]; then
        svc_warn "${target_dir} 不存在，无需卸载"
        return 0
    fi

    cd "${target_dir}"

    # 停止并移除容器
    if [[ -f "docker-compose.yml" ]]; then
        docker compose down --remove-orphans 2>/dev/null || true
        svc_info "容器已停止并移除"
    fi

    # 确认是否删除数据
    read -rp "是否删除数据目录 ${target_dir}？(y/N): " confirm
    if [[ "${confirm}" == "y" || "${confirm}" == "Y" ]]; then
        rm -rf "${target_dir}"
        svc_info "数据目录已删除: ${target_dir}"
    else
        svc_warn "数据目录已保留: ${target_dir}"
    fi
}