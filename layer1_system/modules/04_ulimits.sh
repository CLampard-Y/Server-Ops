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
    if [[ -f /etc/pam.d/common-session ]]; then
        grep -q "pam_limits.so" /etc/pam.d/common-session || \
            echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi

    # ── systemd 全局文件描述符限制 ──
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/99-server-ops-limits.conf << 'SYSD_EOF'
[Manager]
DefaultLimitNOFILE=1048576
SYSD_EOF

    systemctl daemon-reload
    info "ulimit nofile 已设为 1048576（重新登录后对 shell 生效）"
}