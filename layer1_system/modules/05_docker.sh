#!/usr/bin/env bash
# ===========================================================
#  Module 05: Docker + Docker Compose 安装
#  调用方式: 由 install_core.sh source 加载
# ===========================================================

run_05_docker() {
    step "5/7" "安装 Docker & Docker Compose"

    if command -v docker &> /dev/null; then
        info "Docker 已存在，跳过安装: $(docker --version)"
    else
        # 添加 Docker 官方 GPG key
        install -m 0755 -d /etc/apt/keyrings
        local distro_id codename
        distro_id=$(. /etc/os-release && echo "$ID")
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")

        curl -fsSL "https://download.docker.com/linux/${distro_id}/gpg" | \
            gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # 添加 Docker 仓库
        cat > /etc/apt/sources.list.d/docker.list << DOCKER_EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro_id} ${codename} stable
DOCKER_EOF

        apt-get update -qq
        apt-get install -y -qq \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin \
            > /dev/null 2>&1

        systemctl enable --now docker
        info "Docker 安装完成: $(docker --version)"
    fi

    # 验证 Docker Compose
    if docker compose version &> /dev/null; then
        info "Docker Compose: $(docker compose version --short)"
    else
        error "Docker Compose 插件安装失败，请检查"
    fi
}