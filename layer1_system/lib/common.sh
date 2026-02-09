#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — 公共函数库
#  所有模块通过 source 加载此文件，获得统一的日志与检查函数
# ===========================================================

# ── 防止重复 source ──
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

# ── 颜色常量 ──
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# ── 日志函数 ──
info()  { echo -e "${C_GREEN}[✓ DONE]${C_NC} $*"; }
warn()  { echo -e "${C_YELLOW}[! WARN]${C_NC} $*"; }
error() { echo -e "${C_RED}[✗ FAIL]${C_NC} $*"; exit 1; }

step() {
    echo -e "\n${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_CYAN}  STEP $1: $2${C_NC}"
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
}

banner() {
    echo ""
    echo -e "${C_CYAN}╔══════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_CYAN}║${C_NC}  ${C_BOLD}$1${C_NC}"
    echo -e "${C_CYAN}╚══════════════════════════════════════════════════╝${C_NC}"
    echo ""
}

# ── 前置检查 ──
require_root() {
    [[ $EUID -ne 0 ]] && error "请使用 root 权限运行: sudo bash $0"
}

require_debian_like() {
    if [[ ! -f /etc/os-release ]]; then
        error "无法检测操作系统，仅支持 Debian/Ubuntu"
    fi
    local id
    id=$(. /etc/os-release && echo "${ID}")
    if [[ "${id}" != "debian" && "${id}" != "ubuntu" ]]; then
        error "当前系统 ${id} 不受支持，仅支持 Debian/Ubuntu"
    fi
    info "操作系统检测通过: ${id} $(. /etc/os-release && echo "${VERSION_CODENAME}")"
}

# ── 路径解析 ──
# 获取 layer1_system/ 的绝对路径 (无论从哪里调用)
get_layer1_dir() {
    local source_file="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
    local dir
    dir="$(cd "$(dirname "${source_file}")" && pwd)"
    # 如果从 modules/ 子目录调用，向上一级
    if [[ "$(basename "${dir}")" == "modules" || "$(basename "${dir}")" == "lib" ]]; then
        dir="$(dirname "${dir}")"
    fi
    echo "${dir}"
}