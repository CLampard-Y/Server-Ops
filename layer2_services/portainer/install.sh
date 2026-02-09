#!/usr/bin/env bash
# ===========================================================
#  Portainer CE — 安装脚本
#  执行方式: sudo bash /home/Server-Ops/layer2_services/portainer/install.sh
#
#  流程:
#    1. 创建 /home/Basic-Ops/portainer/
#    2. 复制 docker-compose.yml
#    3. docker compose up -d
# ===========================================================
set -euo pipefail

# ── 定位路径 ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER2_LIB="$(dirname "${SCRIPT_DIR}")/lib/service_common.sh"

# ── 加载公共函数库 ──
if [[ -f "${LAYER2_LIB}" ]]; then
    source "${LAYER2_LIB}"
else
    echo "[✗] 找不到 ${LAYER2_LIB}"
    exit 1
fi

# ── 前置检查 ──
svc_require_root
svc_require_docker

# ── 部署 ──
deploy_service "portainer" "${SCRIPT_DIR}"

echo ""
svc_info "Portainer 面板访问地址: https://<服务器IP>:9443"
svc_info "首次访问需设置管理员密码"
echo ""