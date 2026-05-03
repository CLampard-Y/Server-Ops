#!/usr/bin/env bash
# ===========================================================
#  Module 06: Foundry Solidity toolchain
# ===========================================================

run_06_foundry() {
    step "6/10" "安装 Foundry"

    export PATH="${HOME}/.foundry/bin:${PATH}"

    if ! command_in_home foundryup; then
        if command_exists foundryup; then
            warn "检测到非用户级 foundryup: $(command_path foundryup)，将安装用户级 Foundry"
        fi
        info "安装 foundryup..."
        curl -L https://foundry.paradigm.xyz | bash
        export PATH="${HOME}/.foundry/bin:${PATH}"
    else
        info "foundryup 已存在"
    fi

    if ! command_exists foundryup; then
        error "foundryup 不存在，请重新打开 shell 或检查安装日志"
    fi

    foundryup

    info "forge: $(forge --version 2>/dev/null | head -1 || echo unavailable)"
    info "cast:  $(cast --version 2>/dev/null | head -1 || echo unavailable)"
    info "anvil: $(anvil --version 2>/dev/null | head -1 || echo unavailable)"
}
