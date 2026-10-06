<h1 align="center">Chromium — Layer 3</h1>

<p align="center">Remote Chromium with Docker Compose, persistent browser data, and access through an SSH tunnel.</p>

## Quick Start

Prerequisites: Docker Engine and the Docker Compose plugin must be installed and running. The upstream image supports x86-64 and arm64. The default application UID/GID is `1000:1000`; check `id YOUR_USER` and adjust `PUID` / `PGID` in `docker-compose.yml` on another host. Commands below use `sudo`; when logged in as root, omit `sudo`.

Run on the **server**, after this directory is installed under `layer3_apps/chromium/`:

```bash
sudo bash /home/Server-Ops/layer3_apps/deploy_service.sh chromium
```

The existing dispatcher discovers this directory automatically, copies the Compose configuration to `/home/App-Ops/chromium/`, and runs `docker compose up -d`. Docker creates a missing bind-mount directory on a fresh installation. No `.env` or separate installer is required. Initial image download and desktop startup may take time.

Check startup on the **server**:

```bash
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml ps
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml logs --tail=100
```

On your **local computer**, replace `YOUR_USER` and `YOUR_SERVER` with your SSH account and hostname or SSH alias:

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:13001:127.0.0.1:3001 \
  YOUR_USER@YOUR_SERVER
```

Keep the SSH session open and visit **https://localhost:13001** in your local browser. A certificate warning is expected because the container uses self-signed HTTPS. The desktop should appear after startup. Chromium runs on the server and uses its network connection.

> 中文：服务器上执行一条部署命令，本地电脑建立 SSH 隧道，再打开 `https://localhost:13001`。首次启动需等待镜像下载和桌面初始化；root 登录时省略命令中的 `sudo`。

## Configuration and storage

| Location | Purpose |
| --- | --- |
| `/home/Server-Ops/layer3_apps/chromium/` | Deployment recipe and this README |
| `/home/App-Ops/chromium/` | Runtime Compose configuration copied by the dispatcher |
| `/home/App-Data/chromium/config/` | Container `/config`: browser profile, settings, cookies and files saved there |

Keep browser data outside `/home/App-Ops/chromium/`: the dispatcher's configuration synchronization can delete files in that directory during redeployment. The absolute mount preserves browser data when the container is recreated. Treat the profile directory and its backups as private; they can contain active login sessions.

Defaults:

- `PUID=1000`, `PGID=1000`: application user mapping.
- `TZ=Asia/Shanghai`.
- `127.0.0.1:3001:3001`: publish HTTPS on the server's loopback address.
- `shm_size: 1gb`: browser shared-memory limit; neither a startup reservation nor a total RAM limit.
- `restart: unless-stopped`: automatic restart unless explicitly stopped.
- JSON log rotation at `10m`, retaining up to three files.

Edit the **repository** Compose file and redeploy with the same deployment command to customize these defaults. The dispatcher prompts before replacing an existing deployment. Runtime configuration edits can be overwritten by redeployment.

If an existing data directory causes permission errors, confirm the UID/GID and correct ownership only within Chromium's data directory. For the default mapping:

```bash
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml down
sudo chown -R 1000:1000 /home/App-Data/chromium/config
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml up -d
```

> 中文：配置、运行目录、浏览器数据分离；修改仓库 YAML 后重新部署。换服务器时检查 UID/GID，权限修复仅作用于 Chromium 数据目录。

## Access boundary

The upstream interface has no authentication by default and includes a terminal with passwordless `sudo` inside the container. This configuration relies on SSH authentication for remote access. Other users or processes on the server can still reach the loopback port; use a trusted host. A shared host needs additional access controls.

No public port opening, reverse proxy, host desktop installation, Docker socket mount, GPU mapping or privileged mode is required by this configuration. Keep the loopback binding. Public access through a domain requires HTTPS and robust authentication configured before exposure.

Docker isolates application dependencies, consumes host disk space and shares the host kernel. Removing Chromium leaves Docker available for other services. On Docker versions older than 28.0.0, other hosts on the same L2 network may reach localhost-published ports; update Docker before relying on this access boundary.

> 中文：远程入口依赖 SSH 身份验证，不开放公网端口；本机用户仍可访问。Docker 不等于虚拟机级隔离，卸载 Chromium 时保留公共 Docker 底座。

## Maintenance

Run on the **server**:

```bash
# Follow logs; Ctrl+C stops following, not the service.
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml logs -f

# Restart.
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml restart chromium

# Remove the project's containers and network; retain browser data.
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml down

# Start again from the existing runtime configuration.
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml up -d
```

Update the image and recreate the container:

```bash
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml pull chromium
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml up -d chromium
```

The mounted profile remains. Stop the container and back up `/home/App-Data/chromium/config/` before an update when recovery is needed. `latest` changes over time; use a verified version tag or image digest in the repository Compose file when exact image reproducibility is required. Updates are manual.

If server port 3001 is occupied, change the host side of the mapping (for example `127.0.0.1:13002:3001`) and the SSH tunnel's remote destination to match. If local port 13001 is occupied, change only the tunnel's local port and the URL you visit.

> 中文：更新通过拉取镜像并重建容器完成，数据保留；重要更新前停机备份 profile。处理端口冲突时，区分服务器端口与本地隧道端口。

## Uninstall

First remove the project's containers and network:

```bash
sudo docker compose -f /home/App-Ops/chromium/docker-compose.yml down
```

**Continue only after that command succeeds.** Remove runtime configuration while keeping the profile for reinstallation:

```bash
sudo rm -rf -- /home/App-Ops/chromium
```

**Optional permanent data deletion:** this erases the profile, cookies, login sessions and downloads saved under this directory. Back up what you need first.

```bash
sudo rm -rf -- /home/App-Data/chromium
```

Optionally remove the current image if no other container needs it:

```bash
sudo docker image rm lscr.io/linuxserver/chromium:latest
```

If another container references the image, do not force removal. Updates can leave earlier untagged images; inspect `sudo docker image ls` and remove only identified, unused Chromium image IDs if needed. Keep the repository recipe for future deployment. Avoid global `docker system prune` because it can affect unrelated Docker resources.

> 中文：先成功执行 `down`，再删除运行配置；数据需另行明确删除。镜像只定向清理，不强制删除，不使用全局 prune。仓库模板可以保留以便重装。

## References and validation scope

- [LinuxServer Chromium documentation](https://docs.linuxserver.io/images/docker-chromium/): image, HTTPS, user mapping, storage, security and updates.
- [Docker port publishing](https://docs.docker.com/engine/network/port-publishing/): loopback publishing and version caveats.
- [Docker Compose down](https://docs.docker.com/reference/cli/docker/compose/down/): project removal; bind-mounted data remains separate.
- [Deployment dispatcher](../deploy_service.sh): service discovery and configuration synchronization. README files are excluded from normal rsync synchronization; read this guide in the source repository.

Compose parsing and dispatcher discovery checks establish configuration integration. Actual image download, desktop startup, SSH access and browser behavior require verification after deployment; this guide does not claim that those runtime checks have already passed.
