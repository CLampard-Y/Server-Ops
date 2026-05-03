#!/usr/bin/env bash
# ===========================================================
#  Module 06: Swap 保险 (防 OOM)
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_06_swap() {
    step "6/7" "创建 Swap 保险 (防 OOM)"

    local swap_size="2G"
    local swap_size_mb=2048  # 2G = 2048MB
    local swapfile="/swapfile"

    local current_swap_mb
    current_swap_mb=$(free -m | awk '/Swap/{print $2}')

    if [[ ${current_swap_mb} -ge ${swap_size_mb} ]]; then
        info "Swap 已存在且足够: $(free -h | awk '/Swap/{print $2}')，跳过"
        return 0
    fi

    warn "当前 Swap 为 ${current_swap_mb}MB，小于目标 ${swap_size}，将补充 Server-Ops swapfile"

    if swapon --show=NAME --noheadings | grep -Fxq "${swapfile}"; then
        warn "${swapfile} 已启用但总 Swap 仍不足，将仅重建 ${swapfile}"
        swapoff "${swapfile}"
    fi

    if [[ -f "${swapfile}" ]]; then
        rm -f "${swapfile}"
    fi

    info "正在创建 ${swap_size} swap 文件: ${swapfile}"
    if ! fallocate -l "${swap_size}" "${swapfile}" 2>/dev/null; then
        warn "fallocate 不可用或失败，改用 dd 创建 swapfile"
        dd if=/dev/zero of="${swapfile}" bs=1M count="${swap_size_mb}" status=none
    fi

    chmod 600 "${swapfile}"
    mkswap "${swapfile}" > /dev/null
    swapon "${swapfile}"

    # 写入 fstab 持久化
    local fstab_backup
    fstab_backup="/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
    cp /etc/fstab "${fstab_backup}"

    if grep -qE '^[[:space:]]*/swapfile[[:space:]]+none[[:space:]]+swap[[:space:]]+' /etc/fstab; then
        info "fstab 已存在 ${swapfile} 条目"
    else
        echo "${swapfile} none swap sw 0 0" >> /etc/fstab
        info "已写入 fstab，并备份原文件: ${fstab_backup}"
    fi

    info "Swap ${swap_size} 已创建并启用"
}
