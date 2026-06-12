# subconverter 部署指南

subconverter 是一个订阅转换服务，适合在本仓库的 `Layer 3` 中作为独立 Docker 应用统一部署。

## 为什么这里不挂载 `./base`

官方镜像已经内置默认配置。为了保持仓库配置与运行时状态分离，本服务默认不在 `layer3_apps/subconverter/` 下创建 `data` 或 `base` 目录。

如果直接把一个空目录挂载到容器的 `/base`，会覆盖镜像内置配置，反而可能导致服务无法正常工作。需要自定义 `pref`、rules、snippets 或 profiles 时，更推荐先使用自定义镜像，或确认完整 `base` 目录已经准备好后，再挂载到 `/home/App-Data/subconverter/`。

## 部署步骤

### 1. 使用统一部署脚本发布

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh subconverter
```

### 2. 验证服务

默认只监听宿主机本地地址：

```bash
curl http://127.0.0.1:25500/version
```

如果返回类似 `subconverter vx.x.x backend`，说明服务已正常启动。

### 3. 查看日志

```bash
cd /home/App-Ops/subconverter
docker compose logs -f
```

## 目录说明

- 仓库配置目录: `/home/Server-Ops/layer3_apps/subconverter/`
- 运行目录: `/home/App-Ops/subconverter/`
- 默认数据策略: 不向仓库目录写入运行时数据

## 网络说明

当前 compose 使用本地端口绑定：

```yaml
ports:
  - "127.0.0.1:25500:25500"
```

这意味着服务只允许宿主机本机访问。若需要公网访问，建议优先使用 Nginx / Caddy 反向代理，并配置 HTTPS、访问控制或来源 IP 限制。

如果你明确要直接暴露端口，可以改成：

```yaml
ports:
  - "25500:25500"
```

但不建议在没有访问控制的情况下直接暴露。

## 安全建议

### 1. 不要公开泄露订阅 URL

subconverter 的请求中通常会包含原始订阅地址。订阅 URL 应视为敏感信息，避免出现在公开日志、公开面板或第三方反向代理日志中。

### 2. 谨慎开放配置更新接口

官方文档提供了 `updateconf` 接口示例，并提示需要修改默认 token。生产环境不要在默认 token 或无访问控制的情况下暴露该接口。

### 3. 生产环境建议固定镜像版本

当前使用 `tindy2013/subconverter:latest` 便于快速部署。长期稳定运行时，建议改成明确版本或 digest，降低上游镜像变化导致的回归风险。

## 常用命令

```bash
# 重新部署 subconverter
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh subconverter

# 查看所有 Layer 3 服务状态
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh --status

# 进入运行目录
cd /home/App-Ops/subconverter

# 重启服务
docker compose restart

# 停止服务
docker compose down
```
