#!/usr/bin/env bash
# ===========================================================
#  Module 03: 用户级 Node.js via fnm
# ===========================================================

run_03_node_fnm() {
    step "3/10" "安装用户级 Node.js"

    local node_version="${NODE_VERSION:-22}"

    export PATH="${HOME}/.local/share/fnm:${PATH}"

    if ! command_exists fnm; then
        info "安装 fnm 到用户目录..."
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
        export PATH="${HOME}/.local/share/fnm:${PATH}"
    else
        info "fnm 已存在: $(fnm --version)"
    fi

    if ! command_exists fnm; then
        error "fnm 安装失败，请检查网络或 PATH"
    fi

    eval "$(fnm env --use-on-cd --shell bash)"

    info "安装 Node.js ${node_version}..."
    fnm install "${node_version}"
    fnm default "${node_version}"
    fnm use "${node_version}"

    info "Node: $(node --version)"
    info "npm:  $(npm --version)"
}
