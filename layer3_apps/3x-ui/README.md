# 3x-ui 部署指南

3x-ui 是基于 Xray 的代理管理面板，适合在本仓库的 `Layer 3` 中作为业务应用统一部署。

## 为什么这里不用官方的 `./db` / `./cert`

本仓库的 Layer 3 使用 `layer3_apps/deploy_service.sh` 将仓库目录同步到运行目录 `/home/App-Ops/<服务名>/` 后再启动容器。

为了避免后续重部署时运行时数据被同步逻辑覆盖，`docker-compose.yml` 将数据库与证书目录固定挂载到宿主机绝对路径：

- `/home/App-Data/3x-ui/db`
- `/home/App-Data/3x-ui/cert`

这样仓库配置与运行时数据就分离了。

## 部署步骤

### 1. 创建数据目录并限制权限

```bash
sudo install -d -m 700 /home/App-Data/3x-ui/db /home/App-Data/3x-ui/cert
```

如果你后续把证书私钥放进 `/home/App-Data/3x-ui/cert`，建议同时确保私钥文件权限为 `600`。

### 2. 使用统一部署脚本发布

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh 3x-ui
```

### 3. 查看运行状态

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh --status
```

或直接查看日志：

```bash
cd /home/App-Ops/3x-ui
docker compose logs -f
```

## 目录说明

- 仓库配置目录: `/home/Server-Ops/layer3_apps/3x-ui/`
- 运行目录: `/home/App-Ops/3x-ui/`
- 数据目录: `/home/App-Data/3x-ui/db`
- 证书目录: `/home/App-Data/3x-ui/cert`

## 网络说明

当前 compose 使用 `network_mode: host`：

- `3x-ui` 面板和 Xray 入站端口直接监听宿主机网络
- compose 内不会显式声明 `ports:`
- 你需要自己规划面板端口与各代理端口，避免与宿主机已有服务冲突
- 若服务器启用了防火墙，还需要按实际使用端口放行

## 安全建议

### 1. 不要把管理面板直接裸露给全网

更推荐的方式：

- 仅允许你自己的 IP 访问
- 或通过 Nginx / Caddy 反向代理后挂 HTTPS
- 或仅通过 Tailscale / WireGuard / SSH 隧道访问管理面板

### 2. SSL 证书不是全部安全措施

SSL 只能保护传输链路，不等于面板本身安全。即使装了证书，也仍然建议：

- 使用强密码
- 定期更新镜像
- 生产环境尽量将镜像 tag 从 `latest` 固定为明确版本
- 避免默认端口直接裸露
- 仅开放必要的代理业务端口

### 3. host 网络模式需要特别注意端口冲突

由于使用宿主机网络，`3x-ui` 新建的监听端口会直接占用宿主机端口。部署前请确认不会和如下服务冲突：

- `s-ui`
- `alist`
- `komari`
- `portainer`
- 其他已运行的代理或 Web 服务

### 4. 定期备份数据目录

建议至少备份以下路径：

- `/home/App-Data/3x-ui/db`
- `/home/App-Data/3x-ui/cert`

## 常用命令

```bash
# 重新部署 3x-ui
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh 3x-ui

# 进入运行目录
cd /home/App-Ops/3x-ui

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down
```
