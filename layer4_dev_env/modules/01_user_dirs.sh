#!/usr/bin/env bash
# ===========================================================
#  Module 01: 用户开发目录初始化
# ===========================================================

run_01_user_dirs() {
    step "1/10" "初始化用户开发目录"

    local dirs=(
        "${HOME}/.local/bin"
        "${HOME}/.local/share"
        "${HOME}/.cache"
        "${HOME}/code/solidity"
        "${HOME}/code/zk"
        "${HOME}/code/practice"
        "${HOME}/code/audits"
        "${HOME}/code/research"
        "${HOME}/code/benchmarks"
    )

    mkdir -p "${dirs[@]}"
    ensure_dir_private "${HOME}/.config"
    ensure_dir_private "${HOME}/.config/opencode"
    info "开发目录已就绪: ${HOME}/code"
}
