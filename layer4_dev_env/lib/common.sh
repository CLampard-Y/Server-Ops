#!/usr/bin/env bash
# ===========================================================
#  Server-Ops — Layer 4 common helpers
#  Layer 4 is user-scoped and must not require root by default.
# ===========================================================

[[ -n "${_LAYER4_COMMON_SH_LOADED:-}" ]] && return 0
_LAYER4_COMMON_SH_LOADED=1

readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

command_path() {
    command -v "$1" 2>/dev/null || true
}

command_in_home() {
    local cmd="$1"
    local path real_path home_real
    path="$(command_path "${cmd}")"
    [[ -n "${path}" ]] || return 1
    [[ "${path}" == /* ]] || return 1

    home_real="$(cd "${HOME}" && pwd -P)"
    real_path="$(readlink -f "${path}" 2>/dev/null || realpath "${path}" 2>/dev/null || printf '%s' "${path}")"

    [[ "${real_path}" == "${home_real}" || "${real_path}" == "${home_real}/"* ]]
}

require_command() {
    command_exists "$1" || error "缺少必要命令: $1"
}

ensure_npm_user_scoped() {
    require_command npm

    local prefix
    prefix="$(npm config get prefix 2>/dev/null || true)"
    [[ -n "${prefix}" ]] || error "无法读取 npm global prefix"

    require_home_path "${prefix}" "npm global prefix"
}

require_not_empty() {
    local value="$1"
    local name="$2"
    [[ -n "${value}" ]] || error "${name} 不能为空"
}

require_home_path() {
    local path="$1"
    local label="$2"
    local home_real probe probe_real

    require_not_empty "${path}" "${label}"
    require_not_empty "${HOME:-}" "HOME"
    [[ "${path}" == /* ]] || error "${label} 必须是 HOME 下的绝对路径: ${path}"

    case "${path}" in
        */../*|*/..) error "${label} 不能包含路径穿越 '..': ${path}" ;;
    esac

    case "${path}" in
        "${HOME}"|"${HOME}/"*) ;;
        *) error "${label} 必须位于 HOME 下: ${path}" ;;
    esac

    home_real="$(cd "${HOME}" && pwd -P)"

    probe="${path}"
    while [[ ! -e "${probe}" && "${probe}" != "/" ]]; do
        probe="$(dirname "${probe}")"
    done

    [[ -d "${probe}" ]] || error "${label} 的已存在路径不是目录: ${probe}"

    probe_real="$(cd "${probe}" && pwd -P)"
    case "${probe_real}" in
        "${home_real}"|"${home_real}/"*) ;;
        *) error "${label} 解析后不在 HOME 下: ${probe_real}" ;;
    esac
}

ensure_user_mode() {
    if [[ ${EUID} -eq 0 && "${ALLOW_LAYER4_ROOT:-0}" != "1" ]]; then
        error "Layer 4 默认禁止 root 执行。请使用 VS Code Remote-SSH 的开发用户运行；如明确要安装到 /root，请设置 ALLOW_LAYER4_ROOT=1。"
    elif [[ ${EUID} -eq 0 ]]; then
        warn "ALLOW_LAYER4_ROOT=1 已启用，工具将安装到 /root。"
    fi
}

ensure_dir_private() {
    local dir="$1"
    mkdir -p "${dir}"
    chmod 700 "${dir}"
}

ensure_file() {
    local file="$1"
    mkdir -p "$(dirname "${file}")"
    touch "${file}"
}

replace_managed_block() {
    local file="$1"
    local begin_marker="$2"
    local end_marker="$3"
    local content="$4"
    local tmp_file

    ensure_file "${file}"

    local state backup_file line
    state=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == "${begin_marker}" ]]; then
            [[ "${state}" == "0" ]] || error "${file} 中 managed block 嵌套，请手动修复后重试"
            state=1
        elif [[ "${line}" == "${end_marker}" ]]; then
            [[ "${state}" == "1" ]] || error "${file} 中 managed block 结束标记顺序错误，请手动修复后重试"
            state=0
        fi
    done < "${file}"
    [[ "${state}" == "0" ]] || error "${file} 中 managed block 缺少结束标记，请手动修复后重试"

    backup_file="${file}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${file}" "${backup_file}"

    tmp_file="$(mktemp "$(dirname "${file}")/.layer4.XXXXXX")"

    awk -v begin="${begin_marker}" -v end="${end_marker}" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        skip != 1 { print }
    ' "${file}" > "${tmp_file}"

    {
        cat "${tmp_file}"
        printf '\n%s\n' "${begin_marker}"
        printf '%s\n' "${content}"
        printf '%s\n' "${end_marker}"
    } > "${tmp_file}.new"

    mv "${tmp_file}.new" "${file}"
    rm -f "${tmp_file}"
    info "已备份原文件: ${backup_file}"
}

load_bashrc_for_current_shell() {
    # shellcheck disable=SC1090
    [[ -f "${HOME}/.bashrc" ]] && source "${HOME}/.bashrc" || true
}
