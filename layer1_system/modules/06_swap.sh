#!/usr/bin/env bash
# ===========================================================
#  Module 06: Swap 保险 (防 OOM)
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_06_swap() {
    step "6/7" "创建 Swap 保险 (防 OOM)"

    local swap_size="2G"

    if [[ $(swapon --show | wc -l) -gt 0 ]]; then
        info "Swap 已存在: $(free -h | awk '/Swap/{print $2}')，跳过"
    else
        warn "未检测到 Swap，正在创建 ${swap_size}..."
        fallocate -l ${swap_size} /swapfile
        chmod 600 /swapfile
        mkswap /swapfile > /dev/null
        swapon /swapfile

        # 写入 fstab 持久化
        if ! grep -q '/swapfile' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
        info "Swap ${swap_size} 已创建并启用"
    fi
}