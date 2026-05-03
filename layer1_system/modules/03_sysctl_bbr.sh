#!/usr/bin/env bash
# ===========================================================
#  Module 03: 内核参数优化 + BBR 拥塞控制
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_03_sysctl_bbr() {
    step "3/7" "应用内核参数优化 (sysctl + BBR)"

    local sysctl_src="${LAYER1_DIR}/conf/sysctl_optim.conf"
    local sysctl_dst="/etc/sysctl.d/99-server-ops-optim.conf"
    local sysctl_log sysctl_conf_backup sysctl_dst_backup
    sysctl_log="$(mktemp)"
    sysctl_conf_backup=""
    sysctl_dst_backup=""

    if [[ -f "${sysctl_src}" ]]; then
        if [[ -f /etc/sysctl.conf ]]; then
            sysctl_conf_backup="/etc/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)"
            cp /etc/sysctl.conf "${sysctl_conf_backup}"
            if grep -Eq '^[[:space:]]*(fs\.file-max|net\.core\.default_qdisc|net\.ipv4\.tcp_congestion_control)[[:space:]]*=' /etc/sysctl.conf; then
                sed -i -E 's/^([[:space:]]*(fs\.file-max|net\.core\.default_qdisc|net\.ipv4\.tcp_congestion_control)[[:space:]]*=.*)$/# Server-Ops disabled conflicting setting: \1/' /etc/sysctl.conf
                warn "已备份并注释 /etc/sysctl.conf 中的冲突 sysctl: ${sysctl_conf_backup}"
            fi
        fi

        if [[ -f "${sysctl_dst}" ]]; then
            sysctl_dst_backup="${sysctl_dst}.bak.$(date +%Y%m%d%H%M%S)"
            cp "${sysctl_dst}" "${sysctl_dst_backup}"
        fi

        cp "${sysctl_src}" "${sysctl_dst}"

        if command -v modprobe >/dev/null 2>&1; then
            modprobe tcp_bbr 2>/dev/null || warn "tcp_bbr 模块无法加载，可能已内建或当前内核不支持"
        fi

        local available_cc
        available_cc="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || true)"
        if [[ " ${available_cc} " != *" bbr "* ]]; then
            warn "当前内核未报告 BBR 可用，将跳过 tcp_congestion_control=bbr"
            sed -i '/^[[:space:]]*net\.ipv4\.tcp_congestion_control[[:space:]]*=/d' "${sysctl_dst}"
        fi

        if ! sysctl --system > "${sysctl_log}" 2>&1; then
            if [[ -n "${sysctl_conf_backup}" && -f "${sysctl_conf_backup}" ]]; then
                cp "${sysctl_conf_backup}" /etc/sysctl.conf
            fi
            if [[ -n "${sysctl_dst_backup}" && -f "${sysctl_dst_backup}" ]]; then
                cp "${sysctl_dst_backup}" "${sysctl_dst}"
            else
                rm -f "${sysctl_dst}"
            fi
            sysctl --system >/dev/null 2>&1 || warn "回滚后的 sysctl --system 仍失败，请人工检查现有 sysctl 配置"
            warn "sysctl --system 失败，输出如下:"
            while IFS= read -r line; do
                echo "  ${line}" >&2
            done < "${sysctl_log}"
            rm -f "${sysctl_log}"
            error "内核参数应用失败，已回滚 sysctl 配置"
        fi
        rm -f "${sysctl_log}"
        info "内核参数已从 ${sysctl_src} 加载"
    else
        rm -f "${sysctl_log}"
        error "找不到 ${sysctl_src}，请确认仓库结构完整"
    fi

    # 验证 BBR
    local bbr_status
    bbr_status=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    if [[ "${bbr_status}" == "bbr" ]]; then
        info "BBR 拥塞控制: 已生效 ✓"
    else
        warn "BBR 当前值: ${bbr_status}（可能需要重启生效，内核需 >= 4.9）"
    fi

    # 验证 file-max
    info "fs.file-max = $(sysctl -n fs.file-max 2>/dev/null)"
}
