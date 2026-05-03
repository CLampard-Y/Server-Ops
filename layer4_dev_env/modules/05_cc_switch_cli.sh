#!/usr/bin/env bash
# ===========================================================
#  Module 05: cc-switch-cli
# ===========================================================

run_05_cc_switch_cli() {
    step "5/10" "安装 cc-switch-cli"

    local install_dir="${HOME}/.local/bin"
    mkdir -p "${install_dir}"
    export PATH="${install_dir}:${PATH}"

    if command_in_home cc-switch; then
        info "cc-switch 已存在: $(cc-switch --version 2>/dev/null || echo installed)"
    else
        if command_exists cc-switch; then
            warn "检测到非用户级 cc-switch: $(command_path cc-switch)，将安装用户级版本到 ${install_dir}"
        fi
        local installer
        installer="$(mktemp)"
        info "下载 cc-switch-cli installer..."
        curl -fsSL https://github.com/SaladDay/cc-switch-cli/releases/latest/download/install.sh -o "${installer}"
        CC_SWITCH_INSTALL_DIR="${install_dir}" bash "${installer}"
        rm -f "${installer}"
        info "cc-switch 安装完成: $(cc-switch --version 2>/dev/null || echo installed)"
    fi

    ensure_dir_private "${HOME}/.cc-switch"
    info "cc-switch 数据目录已就绪: ${HOME}/.cc-switch"
    warn "未创建 provider，未写入 API key。下一步运行: cc-switch --app codex provider add"
}
