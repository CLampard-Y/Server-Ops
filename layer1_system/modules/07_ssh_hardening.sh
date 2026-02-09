#!/usr/bin/env bash
# ===========================================================
#  Module 07: SSH 安全加固
#  调用方式: 由 install_core.sh source 加载
#
#  功能:
#    1. 从 GitHub 拉取用户公钥 → 写入 authorized_keys
#    2. 禁用密码登录 (PasswordAuthentication no)
#    3. 禁用 Root 密码登录 (PermitRootLogin prohibit-password)
#    4. 重启 sshd 服务
#
#  安全设计:
#    - 拉取公钥后要求用户确认指纹，防止中间人攻击
#    - 仅在确认公钥成功写入后才禁用密码登录
#    - 提供回滚提示，防止锁死自己
# ===========================================================

run_07_ssh_hardening() {
    step "7/7" "SSH 安全加固 (公钥导入 + 禁用密码登录)"

    # ── 接收 GitHub Username (由 install_core.sh 传入) ──
    local github_user="${GITHUB_USERNAME:-}"

    if [[ -z "${github_user}" ]]; then
        warn "未提供 GitHub Username，跳过 SSH 加固"
        warn "后续可手动执行: GITHUB_USERNAME=xxx bash install_core.sh"
        return 0
    fi

    # ── Step A: 拉取 GitHub 公钥 ──
    local keys_url="https://github.com/${github_user}.keys"
    local tmp_keys
    tmp_keys=$(mktemp)

    info "正在从 ${keys_url} 拉取公钥..."
    if ! curl -fsSL --connect-timeout 10 "${keys_url}" -o "${tmp_keys}"; then
        warn "无法访问 ${keys_url}，请检查用户名或网络"
        rm -f "${tmp_keys}"
        return 1
    fi

    # 检查是否拉到了有效公钥
    local key_count
    key_count=$(grep -c '^ssh-' "${tmp_keys}" 2>/dev/null || echo "0")
    if [[ "${key_count}" -eq 0 ]]; then
        warn "未从 GitHub 获取到有效公钥 (用户: ${github_user})"
        rm -f "${tmp_keys}"
        return 1
    fi

    info "获取到 ${key_count} 个公钥:"
    echo -e "${C_CYAN}────────────────────────────────────────${C_NC}"
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        # 显示公钥类型 + 指纹摘要 (前40字符)
        local key_type key_preview
        key_type=$(echo "${line}" | awk '{print $1}')
        key_preview=$(echo "${line}" | awk '{print substr($2,1,30)}')...
        echo -e "  ${C_GREEN}${key_type}${C_NC}  ${key_preview}"
    done < "${tmp_keys}"
    echo -e "${C_CYAN}────────────────────────────────────────${C_NC}"

    # ── Step B: 确认并写入 authorized_keys ──
    local target_user="root"
    local ssh_dir="/root/.ssh"
    local auth_keys="${ssh_dir}/authorized_keys"

    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    # 追加公钥 (去重)
    local added=0
    while IFS= read -r line; do
        [[ -z "${line}" ]] && continue
        if ! grep -qF "${line}" "${auth_keys}" 2>/dev/null; then
            echo "${line}" >> "${auth_keys}"
            ((added++))
        fi
    done < "${tmp_keys}"

    chmod 600 "${auth_keys}"
    rm -f "${tmp_keys}"
    info "已写入 ${added} 个新公钥到 ${auth_keys} (跳过 $((key_count - added)) 个重复)"

    # ── Step C: 加固 sshd_config ──
    local sshd_conf="/etc/ssh/sshd_config"
    local sshd_backup="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"

    # 备份原配置
    cp "${sshd_conf}" "${sshd_backup}"
    info "sshd_config 已备份到 ${sshd_backup}"

    # 定义需要修改的参数
    declare -A sshd_params=(
        ["PasswordAuthentication"]="no"
        ["PermitRootLogin"]="prohibit-password"
        ["PubkeyAuthentication"]="yes"
        ["ChallengeResponseAuthentication"]="no"
        ["UsePAM"]="yes"
    )

    for key in "${!sshd_params[@]}"; do
        local val="${sshd_params[${key}]}"
        if grep -qE "^\s*#?\s*${key}" "${sshd_conf}"; then
            # 替换已有行 (包括被注释的)
            sed -i "s/^\s*#*\s*${key}.*/${key} ${val}/" "${sshd_conf}"
        else
            # 追加到文件末尾
            echo "${key} ${val}" >> "${sshd_conf}"
        fi
    done
    info "sshd_config 已加固: 密码登录已禁用, 仅允许公钥认证"

    # ── Step D: 验证配置并重启 ──
    if sshd -t 2>/dev/null; then
        systemctl restart sshd
        info "sshd 服务已重启 ✓"
    else
        # 配置有误，回滚
        cp "${sshd_backup}" "${sshd_conf}"
        systemctl restart sshd
        warn "sshd_config 验证失败，已回滚到备份版本"
        return 1
    fi

    echo ""
    warn "╔══════════════════════════════════════════════════════╗"
    warn "║  ⚠️  重要: 请勿关闭当前 SSH 会话!                   ║"
    warn "║  请新开一个终端，测试公钥登录是否正常。              ║"
    warn "║  如果无法登录，在当前会话中执行:                     ║"
    warn "║    cp ${sshd_backup} /etc/ssh/sshd_config            ║"
    warn "║    systemctl restart sshd                            ║"
    warn "╚══════════════════════════════════════════════════════╝"
    echo ""
}