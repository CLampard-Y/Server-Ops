#!/usr/bin/env bash
# ===========================================================
#  Module 07: SSH 安全加固
#  调用方式: 由 install_core.sh source 加载
#
#  功能:
#    1. 从 GitHub 拉取用户公钥，写入目标用户 authorized_keys
#    2. 通过 managed drop-in 配置 sshd 安全参数
#    3. 验证 sshd 配置后 reload/restart SSH 服务
#
#  安全设计:
#    - 默认目标用户为 sudo 发起者；直接 root 执行时为 root
#    - 不直接在文件末尾追加 sshd 参数，避免落入 Match block
#    - 验证失败会回滚 sshd_config 与 drop-in
# ===========================================================

_layer1_ssh_service_reload() {
    if systemctl reload ssh.service 2>/dev/null; then
        info "SSH 服务已 reload: ssh.service"
    elif systemctl reload sshd.service 2>/dev/null; then
        info "SSH 服务已 reload: sshd.service"
    elif systemctl restart ssh.service 2>/dev/null; then
        info "SSH 服务已 restart: ssh.service"
    elif systemctl restart sshd.service 2>/dev/null; then
        info "SSH 服务已 restart: sshd.service"
    else
        error "找不到可 reload/restart 的 SSH systemd 服务 (ssh.service/sshd.service)"
    fi
}

_layer1_ssh_rollback() {
    local sshd_conf="$1"
    local sshd_backup="$2"
    local sshd_dropin="$3"
    local dropin_backup="$4"

    cp "${sshd_backup}" "${sshd_conf}"
    if [[ -n "${dropin_backup}" && -f "${dropin_backup}" ]]; then
        cp "${dropin_backup}" "${sshd_dropin}"
    else
        rm -f "${sshd_dropin}"
    fi
    _layer1_ssh_service_reload
}

run_07_ssh_hardening() {
    step "7/7" "SSH 安全加固 (公钥导入 + 禁用密码登录)"

    local github_user="${GITHUB_USERNAME:-}"
    if [[ -z "${github_user}" ]]; then
        warn "未提供 GitHub Username，跳过 SSH 加固"
        warn "后续可手动执行: GITHUB_USERNAME=xxx bash install_core.sh"
        return 0
    fi
    if ! [[ "${github_user}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
        error "GitHub Username 格式无效: ${github_user}"
    fi

    local target_user
    target_user="${SSH_TARGET_USER:-${SUDO_USER:-root}}"
    [[ "${target_user}" == "root" || "${target_user}" != "" ]] || error "SSH_TARGET_USER 不能为空"

    local target_home target_group passwd_entry
    passwd_entry="$(getent passwd "${target_user}" || true)"
    [[ -n "${passwd_entry}" ]] || error "目标用户不存在: ${target_user}"
    target_home="$(cut -d: -f6 <<< "${passwd_entry}")"
    target_group="$(id -gn "${target_user}" 2>/dev/null || true)"
    [[ -n "${target_home}" && -d "${target_home}" ]] || error "无法解析目标用户 HOME: ${target_user}"
    [[ -n "${target_group}" ]] || error "无法解析目标用户主组: ${target_user}"

    local keys_url="https://github.com/${github_user}.keys"
    local tmp_keys
    tmp_keys=$(mktemp)

    info "正在从 ${keys_url} 拉取公钥..."
    if ! curl -fsSL --connect-timeout 10 "${keys_url}" -o "${tmp_keys}"; then
        rm -f "${tmp_keys}"
        error "无法访问 ${keys_url}，请检查用户名或网络"
    fi

    local key_count
    key_count=$(grep -cE '^(ssh-|ecdsa-|sk-)' "${tmp_keys}" 2>/dev/null || true)
    key_count="${key_count:-0}"
    if [[ "${key_count}" -eq 0 ]]; then
        rm -f "${tmp_keys}"
        error "未从 GitHub 获取到有效公钥 (用户: ${github_user})"
    fi

    info "获取到 ${key_count} 个公钥:"
    echo -e "${C_CYAN}────────────────────────────────────────${C_NC}"
    while IFS= read -r line; do
        [[ "${line}" =~ ^(ssh-|ecdsa-|sk-) ]] || continue
        local key_type key_preview
        key_type=$(awk '{print $1}' <<< "${line}")
        key_preview=$(awk '{print substr($2,1,30)}' <<< "${line}")...
        echo -e "  ${C_GREEN}${key_type}${C_NC}  ${key_preview}"
    done < "${tmp_keys}"
    echo -e "${C_CYAN}────────────────────────────────────────${C_NC}"

    local ssh_dir auth_keys
    ssh_dir="${target_home}/.ssh"
    auth_keys="${ssh_dir}/authorized_keys"

    install -d -m 700 -o "${target_user}" -g "${target_group}" "${ssh_dir}"
    touch "${auth_keys}"
    chown "${target_user}:${target_group}" "${auth_keys}"
    chmod 600 "${auth_keys}"

    local added=0
    while IFS= read -r line; do
        [[ "${line}" =~ ^(ssh-|ecdsa-|sk-) ]] || continue
        if ! grep -qF "${line}" "${auth_keys}" 2>/dev/null; then
            echo "${line}" >> "${auth_keys}"
            ((++added))
        fi
    done < "${tmp_keys}"
    rm -f "${tmp_keys}"

    chown "${target_user}:${target_group}" "${auth_keys}"
    chmod 600 "${auth_keys}"
    info "已写入 ${added} 个新公钥到 ${auth_keys} (跳过 $((key_count - added)) 个重复)"

    local sshd_bin
    sshd_bin="$(command -v sshd 2>/dev/null || echo /usr/sbin/sshd)"
    [[ -x "${sshd_bin}" ]] || error "找不到 sshd 可执行文件"

    local sshd_conf="/etc/ssh/sshd_config"
    local sshd_dropin_dir="/etc/ssh/sshd_config.d"
    local sshd_dropin="${sshd_dropin_dir}/99-server-ops-hardening.conf"
    local sshd_backup="${sshd_conf}.bak.$(date +%Y%m%d%H%M%S)"
    local dropin_backup=""

    cp "${sshd_conf}" "${sshd_backup}"
    if [[ -f "${sshd_dropin}" ]]; then
        dropin_backup="${sshd_dropin}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${sshd_dropin}" "${dropin_backup}"
    fi

    mkdir -p "${sshd_dropin_dir}"

    if ! grep -qE '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' "${sshd_conf}"; then
        local tmp_conf
        tmp_conf=$(mktemp)
        {
            echo "Include /etc/ssh/sshd_config.d/*.conf"
            cat "${sshd_conf}"
        } > "${tmp_conf}"
        cat "${tmp_conf}" > "${sshd_conf}"
        rm -f "${tmp_conf}"
        warn "已在 sshd_config 顶部加入 Include，并备份原文件: ${sshd_backup}"
    else
        info "sshd_config 已包含 drop-in Include"
    fi

    local disable_password_auth
    disable_password_auth="${LAYER1_DISABLE_SSH_PASSWORD_AUTH:-1}"

    {
        echo "# Managed by Server-Ops Layer 1. Do not edit manually."
        echo "PubkeyAuthentication yes"
        echo "PermitRootLogin prohibit-password"
        echo "KbdInteractiveAuthentication no"
        echo "ChallengeResponseAuthentication no"
        echo "UsePAM yes"
        if [[ "${disable_password_auth}" == "1" ]]; then
            echo "PasswordAuthentication no"
        fi
    } > "${sshd_dropin}"

    if ! "${sshd_bin}" -t 2>/dev/null; then
        _layer1_ssh_rollback "${sshd_conf}" "${sshd_backup}" "${sshd_dropin}" "${dropin_backup}"
        error "sshd_config 验证失败，已回滚到备份版本"
    fi

    local ssh_host effective_config
    ssh_host="$(hostname -f 2>/dev/null || hostname)"
    if ! effective_config="$("${sshd_bin}" -T -C "user=${target_user},host=${ssh_host},addr=127.0.0.1" 2>/dev/null)"; then
        _layer1_ssh_rollback "${sshd_conf}" "${sshd_backup}" "${sshd_dropin}" "${dropin_backup}"
        error "无法获取目标用户 ${target_user} 的 sshd 生效配置，已回滚"
    fi

    local effective_pubkey effective_authorized_keys
    effective_pubkey="$(awk '$1 == "pubkeyauthentication" {print $2; exit}' <<< "${effective_config}")"
    effective_authorized_keys="$(awk '$1 == "authorizedkeysfile" {for (i=2;i<=NF;i++) printf "%s ", $i; print ""; exit}' <<< "${effective_config}")"

    if [[ "${effective_pubkey}" != "yes" ]]; then
        _layer1_ssh_rollback "${sshd_conf}" "${sshd_backup}" "${sshd_dropin}" "${dropin_backup}"
        error "PubkeyAuthentication 对目标用户 ${target_user} 未启用，已回滚"
    fi

    if [[ "${effective_authorized_keys}" != *".ssh/authorized_keys"* ]]; then
        _layer1_ssh_rollback "${sshd_conf}" "${sshd_backup}" "${sshd_dropin}" "${dropin_backup}"
        error "目标用户 ${target_user} 的 AuthorizedKeysFile 未包含 .ssh/authorized_keys，已回滚"
    fi

    if grep -qE '^(allowusers|denyusers|allowgroups|denygroups)[[:space:]]+' <<< "${effective_config}"; then
        warn "检测到 AllowUsers/DenyUsers/AllowGroups/DenyGroups，请人工确认 ${target_user} 可登录"
    fi

    if [[ "${disable_password_auth}" == "1" ]]; then
        local effective_password
        effective_password="$(awk '$1 == "passwordauthentication" {print $2; exit}' <<< "${effective_config}")"
        if [[ "${effective_password}" != "no" ]]; then
            _layer1_ssh_rollback "${sshd_conf}" "${sshd_backup}" "${sshd_dropin}" "${dropin_backup}"
            error "PasswordAuthentication 对目标用户 ${target_user} 的生效值不是 no，已回滚"
        fi
    else
        warn "LAYER1_DISABLE_SSH_PASSWORD_AUTH=0，未禁用 SSH 密码登录"
    fi

    _layer1_ssh_service_reload
    info "SSH 已加固，目标用户: ${target_user} (${auth_keys})"

    echo ""
    warn "╔══════════════════════════════════════════════════════╗"
    warn "║  重要: 请勿关闭当前 SSH 会话!                       ║"
    warn "║  请新开一个终端，测试目标用户公钥登录是否正常。      ║"
    warn "║  如果无法登录，在当前会话中执行:                     ║"
    warn "║    cp ${sshd_backup} /etc/ssh/sshd_config            ║"
    if [[ -n "${dropin_backup}" ]]; then
        warn "║    cp ${dropin_backup} ${sshd_dropin}"
    else
        warn "║    rm -f ${sshd_dropin}"
    fi
    warn "║    systemctl reload ssh || systemctl reload sshd      ║"
    warn "╚══════════════════════════════════════════════════════╝"
    echo ""
}
