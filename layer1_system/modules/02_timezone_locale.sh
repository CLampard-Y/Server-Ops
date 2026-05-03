#!/usr/bin/env bash
# ===========================================================
#  Module 02: 时区 + Locale 标准化
#  调用方式: 由 install_core.sh source 加载
#
#  新增/拓展说明 (相比原 PT 脚本):
#    - Locale 标准化: 原脚本仅设时区，未处理 locale。
#      生产服务器若缺少 en_US.UTF-8 会导致 Python/Perl/Docker
#      日志出现编码警告甚至崩溃，此处补全。
# ===========================================================

run_02_timezone_locale() {
    step "2/7" "设置时区 + Locale 标准化"

    # ── 时区 ──
    local timezone
    timezone="${SERVER_OPS_TIMEZONE:-Asia/Shanghai}"
    timedatectl set-timezone "${timezone}"
    info "当前时区: $(timedatectl show --property=Timezone --value)"
    info "当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

    # ── Locale ──
    # 确保 en_US.UTF-8 可用，避免各类编码问题
    if ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
        apt-get install -y -qq \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            locales > /dev/null 2>&1
        sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
        locale-gen > /dev/null 2>&1
        info "en_US.UTF-8 locale 已生成"
    else
        info "en_US.UTF-8 locale 已存在 ✓"
    fi

    update-locale LANG=en_US.UTF-8
    info "默认 locale 已设为 en_US.UTF-8"
}
