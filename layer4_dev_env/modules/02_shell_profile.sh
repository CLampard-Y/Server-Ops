#!/usr/bin/env bash
# ===========================================================
#  Module 02: Shell profile managed block
# ===========================================================

run_02_shell_profile() {
    step "2/10" "配置用户级 PATH"

    local bashrc="${HOME}/.bashrc"
    local begin_marker="# >>> Server-Ops Layer 4 Dev Env >>>"
    local end_marker="# <<< Server-Ops Layer 4 Dev Env <<<"
    local block

    block='export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.foundry/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/share/fnm:$PATH"

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell bash)"
fi'

    replace_managed_block "${bashrc}" "${begin_marker}" "${end_marker}" "${block}"

    export PATH="${HOME}/.local/bin:${HOME}/.foundry/bin:${HOME}/.cargo/bin:${HOME}/.local/share/fnm:${PATH}"
    if command_exists fnm; then
        eval "$(fnm env --use-on-cd --shell bash)"
    fi

    info "已更新 ${bashrc} 的 Server-Ops managed block"
}
