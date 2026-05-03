#!/usr/bin/env bash
# ===========================================================
#  Module 04: 文件描述符限制 (ulimit)
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_04_ulimits() {
    step "4/7" "配置文件描述符限制 (ulimit)"

    # ── limits.conf ──
    cat > /etc/security/limits.d/99-server-ops-nofile.conf << 'LIMITS_EOF'
# Server-Ops — 高并发连接需要大量文件描述符
*    soft    nofile    1048576
*    hard    nofile    1048576
root soft    nofile    1048576
root hard    nofile    1048576
LIMITS_EOF

    # ── 确保 PAM 加载 limits 模块 ──
    local pam_file pam_backup
    for pam_file in /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive; do
        [[ -f "${pam_file}" ]] || continue
        if ! grep -Eq '^[[:space:]]*session[[:space:]]+.*pam_limits\.so' "${pam_file}"; then
            pam_backup="${pam_file}.bak.$(date +%Y%m%d%H%M%S)"
            cp "${pam_file}" "${pam_backup}"
            echo "session required pam_limits.so" >> "${pam_file}"
            info "已为 ${pam_file} 启用 pam_limits.so，备份: ${pam_backup}"
        fi
    done

    # ── systemd 全局文件描述符限制 ──
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/99-server-ops-limits.conf << 'SYSD_EOF'
[Manager]
DefaultLimitNOFILE=1048576
SYSD_EOF

    systemctl daemon-reload
    info "ulimit nofile 已设为 1048576（重新登录后对 shell 生效）"
}
