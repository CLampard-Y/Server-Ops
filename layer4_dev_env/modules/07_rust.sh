#!/usr/bin/env bash
# ===========================================================
#  Module 07: Rust toolchain
# ===========================================================

run_07_rust() {
    step "7/10" "安装 Rust 工具链"

    export PATH="${HOME}/.cargo/bin:${PATH}"

    if command_in_home rustup; then
        info "rustup 已存在: $(rustup --version | head -1)"
    else
        if command_exists rustup; then
            warn "检测到非用户级 rustup: $(command_path rustup)，将安装用户级 Rust"
        fi
        info "安装 rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        export PATH="${HOME}/.cargo/bin:${PATH}"
    fi

    rustup toolchain install stable
    rustup default stable

    info "rustc: $(rustc --version)"
    info "cargo: $(cargo --version)"
}
