#!/usr/bin/env bash
# ===========================================================
#  Module 04: AI coding CLI tools
# ===========================================================

run_04_ai_coding_tools() {
    step "4/10" "安装 AI coding CLI 工具"

    ensure_npm_user_scoped

    if command_in_home codex; then
        info "Codex CLI 已存在: $(codex --version 2>/dev/null || echo installed)"
    else
        if command_exists codex; then
            warn "检测到非用户级 codex: $(command_path codex)，将通过用户级 npm prefix 安装覆盖 PATH 优先级"
        fi
        info "安装 OpenAI Codex CLI (@openai/codex)..."
        npm install -g @openai/codex
        info "Codex CLI 安装完成: $(codex --version 2>/dev/null || echo installed)"
    fi

    ensure_dir_private "${HOME}/.codex"
    info "Codex 配置目录已就绪: ${HOME}/.codex"
    warn "未写入任何 API key；请后续使用 cc-switch-cli 添加 provider。"
}
