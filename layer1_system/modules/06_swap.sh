#!/usr/bin/env bash
# ===========================================================
#  Module 06: Swap 保险 (防 OOM)
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_06_swap() {
    step "6/7" "创建 Swap 保险 (防 OOM)"

    local swap_size="2G"
    local swap_size_mb=2048  # 2G = 2048MB

    # 检查是否存在 swap
    if [[ $(swapon --show | wc -l) -gt 0 ]]; then
        # 获取当前 swap 大小（单位：MB）
        local current_swap_mb
        current_swap_mb=$(free -m | awk '/Swap/{print $2}')
        
        if [[ ${current_swap_mb} -ge ${swap_size_mb} ]]; then
            info "Swap 已存在且足够: $(free -h | awk '/Swap/{print $2}')，跳过"
            return 0
        else
            warn "当前 Swap 仅 ${current_swap_mb}MB，小于目标 ${swap_size}，将重新创建..."
            
            # 关闭现有 swap
            local swap_devices
            swap_devices=$(swapon --show=NAME --noheadings)
            while IFS= read -r swap_dev; do
                [[ -z "${swap_dev}" ]] && continue
                info "关闭 swap: ${swap_dev}"
                swapoff "${swap_dev}"
                
                # 如果是文件类型的 swap，删除它
                if [[ -f "${swap_dev}" ]]; then
                    rm -f "${swap_dev}"
                    info "已删除旧 swap 文件: ${swap_dev}"
                fi
                
                # 从 fstab 中移除
                if grep -q "${swap_dev}" /etc/fstab; then
                    sed -i "\|${swap_dev}|d" /etc/fstab
                    info "已从 /etc/fstab 移除: ${swap_dev}"
                fi
            done <<< "${swap_devices}"
        fi
    else
        warn "未检测到 Swap，正在创建 ${swap_size}..."
    fi

    # 创建新的 swap
    info "正在创建 ${swap_size} swap 文件..."
    fallocate -l ${swap_size} /swapfile
    chmod 600 /swapfile
    mkswap /swapfile > /dev/null
    swapon /swapfile

    # 写入 fstab 持久化
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    info "Swap ${swap_size} 已创建并启用"
}