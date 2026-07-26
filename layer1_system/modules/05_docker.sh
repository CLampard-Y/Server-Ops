#!/usr/bin/env bash
# ===========================================================
#  Module 05: Docker + Docker Compose 安装
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_05_docker() {
    step "5/7" "安装 Docker & Docker Compose"

    local need_install=0
    if command -v docker &> /dev/null; then
        info "Docker 已存在: $(docker --version)"
    else
        need_install=1
    fi

    if ! docker compose version &> /dev/null; then
        need_install=1
        warn "Docker Compose 插件缺失，将安装/修复 Docker CE 组件"
    fi

    if [[ "${need_install}" == "1" ]]; then
        install -m 0755 -d /etc/apt/keyrings
        local distro_id codename architecture apt_log docker_candidate
        distro_id=$(. /etc/os-release && echo "$ID")
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
        architecture="$(dpkg --print-architecture)"
        apt_log="$(mktemp)"

        if ! curl -fsSL "https://download.docker.com/linux/${distro_id}/gpg" | \
            gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg; then
            rm -f "${apt_log}"
            error "Docker 官方 GPG key 下载或写入失败"
        fi
        chmod a+r /etc/apt/keyrings/docker.gpg

        cat > /etc/apt/sources.list.d/docker.list << DOCKER_EOF
deb [arch=${architecture} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro_id} ${codename} stable
DOCKER_EOF

        if ! apt-get update -qq > "${apt_log}" 2>&1; then
            warn "APT update Docker 源失败，输出如下:"
            while IFS= read -r line; do
                echo "  ${line}" >&2
            done < "${apt_log}"
            rm -f "${apt_log}"
            error "Docker 源更新失败"
        fi

        # apt-cache localizes field names (for example, Candidate becomes 候选).
        # Force the C locale before parsing so SSH/client locale cannot change the result.
        docker_candidate="$(
            LC_ALL=C apt-cache policy docker-ce 2>/dev/null | \
                awk '/^[[:space:]]*Candidate:/ { print $2; exit }' || true
        )"
        if [[ -z "${docker_candidate}" || "${docker_candidate}" == "(none)" ]]; then
            warn "Docker CE candidate 检测失败"
            warn "系统/架构: ${distro_id}/${codename} (${architecture})"
            warn "Docker 源: https://download.docker.com/linux/${distro_id} ${codename} stable"
            if [[ -s "${apt_log}" ]]; then
                warn "APT update 输出如下:"
                while IFS= read -r line; do
                    echo "  ${line}" >&2
                done < "${apt_log}"
            fi
            LC_ALL=C apt-cache policy docker-ce >&2 || true
            rm -f "${apt_log}"
            error "当前 Docker 源没有 docker-ce 候选版本: ${distro_id}/${codename}"
        fi
        info "Docker CE candidate: ${docker_candidate}"

        if ! apt-get install -y -qq \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            > "${apt_log}" 2>&1; then
            warn "Docker 组件安装失败，APT 输出如下:"
            while IFS= read -r line; do
                echo "  ${line}" >&2
            done < "${apt_log}"
            rm -f "${apt_log}"
            error "Docker 安装失败"
        fi
        rm -f "${apt_log}"

        info "Docker 安装完成: $(docker --version)"
    fi

    if ! systemctl enable --now docker >/dev/null 2>&1; then
        error "Docker 已安装但服务启动失败，请检查: systemctl status docker"
    fi

    # 验证 Docker Compose
    if docker compose version &> /dev/null; then
        info "Docker Compose: $(docker compose version --short)"
    else
        error "Docker Compose 插件安装失败，请检查"
    fi
}
