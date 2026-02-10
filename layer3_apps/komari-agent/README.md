# Komari Agent 部署指南

Komari Agent 是服务器监控客户端，用于收集服务器性能数据并发送到 Komari Server。

## 快速部署

### 1. 修改配置

编辑 `docker-compose.yml`，修改以下环境变量：

```yaml
environment:
  - KOMARI_SERVER=http://your-komari-server-ip:3399  # 改为你的 Komari Server 地址
  - KOMARI_SECRET=your-secret-key-here                # 改为面板中生成的密钥
```

### 2. 获取密钥

在 Komari Server 面板中：
1. 点击 "添加节点"
2. 系统会生成一个密钥（Secret）
3. 复制这个密钥到 `KOMARI_SECRET` 环境变量

### 3. 部署 Agent

```bash
# 使用统一部署脚本
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh komari-agent

# 或者手动部署
cd /home/App-Ops/komari-agent
docker compose up -d
```

### 4. 查看状态

```bash
cd /home/App-Ops/komari-agent
docker compose logs -f
```

## 配置说明

### 网络模式
使用 `network_mode: host` 以便 Agent 能够准确获取主机网络信息。

### 特权模式
使用 `privileged: true` 以便 Agent 能够访问主机的系统信息。

### 挂载卷说明
- `/proc` - 进程信息
- `/sys` - 系统信息
- `/` - 根文件系统（用于磁盘监控）
- `/var/run/docker.sock` - Docker 容器监控（可选）

## 多服务器部署

如果你有多台服务器需要监控：

1. 在每台服务器上克隆配置仓库
2. 修改各自的 `KOMARI_SECRET`（每台服务器使用不同的密钥）
3. 保持 `KOMARI_SERVER` 指向同一个 Komari Server
4. 分别部署

## 故障排查

### Agent 无法连接到 Server

```bash
# 检查网络连通性
curl http://your-komari-server-ip:3399

# 查看 Agent 日志
docker compose logs komari-agent
```

### 数据不显示

1. 确认 Secret 密钥正确
2. 确认 Server 地址正确
3. 检查防火墙是否开放 3399 端口
4. 查看 Agent 日志是否有错误

## 卸载

```bash
cd /home/App-Ops/komari-agent
docker compose down
rm -rf /home/App-Ops/komari-agent
```
