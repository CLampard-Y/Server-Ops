#!/usr/bin/env bash
# ===========================================================
#  Module 03: 内核参数优化 + BBR 拥塞控制
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_03_sysctl_bbr() {
    step "3/7" "应用内核参数优化 (sysctl + BBR)"

    local sysctl_src="${LAYER1_DIR}/conf/sysctl_optim.conf"
    local sysctl_dst="/etc/sysctl.d/99-server-ops-optim.conf"

    if [[ -f "${sysctl_src}" ]]; then
        # 清除 /etc/sysctl.conf 中与我们配置冲突的条目
        # /etc/sysctl.conf 优先级高于 /etc/sysctl.d/，会覆盖我们的设置
        if [[ -f /etc/sysctl.conf ]]; then
            sed -i '/^[[:space:]]*fs\.file-max/d' /etc/sysctl.conf
            sed -i '/^[[:space:]]*net\.core\.default_qdisc/d' /etc/sysctl.conf
            sed -i '/^[[:space:]]*net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
            info "已清除 /etc/sysctl.conf 中的冲突条目"
        fi

        cp -v "${sysctl_src}" "${sysctl_dst}"
        sysctl --system > /dev/null 2>&1
        info "内核参数已从 ${sysctl_src} 加载"
    else
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