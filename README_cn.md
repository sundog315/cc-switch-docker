# cc-switch 容器（webtop 远程桌面版）离线导入与配置

把 **cc-switch**（farion1231/cc-switch，Tauri 2 桌面工具，用于在多个 LLM 供应商间切换/路由）跑在 Docker 容器里，通过**浏览器**远程操作其图形界面；宿主机本机的 Claude Code 经 cc-switch 的**代理端口 15721** 路由到后端 LLM。

> 解决的根本问题：信创麒麟 aarch64 宿主机 glibc 过低（2.31），跑不动 cc-switch 原生包；用容器规避 glibc 问题，用 web 远程桌面解决「宿主机无本地图形会话、需从另一台电脑操作」。

---

## 产物清单

| 文件 | 说明 |
|---|---|
| `cc-switch-webtop.local.tar.gz` | 镜像压缩包（**1.2GB**），含 webtop 基镜像全部层 + cc-switch，离线自包含 |
| `cc-switch-webtop.local.tar.gz.sha256` | 校验和 |
| `docker-compose.yml` | 运行定义（端口/卷/密码） |
| `README.md` | 本文档 |

镜像 tag：`cc-switch-webtop:local`，架构 **arm64 / linux**。

---

## ⚠️ 前置条件（务必先核对）

1. **架构必须是 aarch64/arm64**。本镜像是 arm64 构建，在 x86_64 机器上 `docker load` 能成功，但 `docker run` 会报 `exec format error`。`uname -m` 应为 `aarch64`。
2. 已装 **Docker**，当前用户在 `docker` 组（免 sudo）。`docker --version` 能跑。
3. 有 **docker-compose**（v1 `docker-compose` 命令，或 v2 `docker compose` 子命令均可）。
4. 目标机器与操作者浏览器在**同一可信内网**（本设计不做 HTTPS 正式证书，依赖内网可信）。
5. 磁盘：镜像解压后约 3.5GB，再加 `/config` 数据卷，预留 ≥ 6GB。

---

## 1. 导入镜像

```bash
# （可选）校验完整性
sha256sum -c cc-switch-webtop.local.tar.gz.sha256

# 导入
docker load -i cc-switch-webtop.local.tar.gz
# 预期输出：Loaded image: cc-switch-webtop:local

# 确认
docker images cc-switch-webtop:local
```

---

## 2. 准备 docker-compose.yml

若包内已带 `docker-compose.yml`，直接编辑其中的 **`PASSWORD`**（务必改掉默认值）。内容参考：

```yaml
version: "3.7"
services:
  cc-switch-webtop:
    image: cc-switch-webtop:local      # 用导入的镜像，不需要 build
    container_name: cc-switch
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Shanghai
      - PASSWORD=改成你的强密码          # 浏览器登录密码
      - WEBKIT_DISABLE_COMPOSITING_MODE=1
    volumes:
      - ./cc-switch-data:/config        # cc-switch 配置/密钥持久化
    ports:
      - "3000:3000"      # 网页 HTTP（Selkies 要求安全上下文，仅同机/调试用）
      - "3001:3001"      # 网页 HTTPS（远程访问用这个）
      - "15721:15721"    # cc-switch 代理（0.0.0.0，纯内网）
    shm_size: "1gb"
    restart: unless-stopped
```

> 注意：导入方**不需要** Dockerfile 和 cc-switch.deb（镜像里已装好）。`./cc-switch-data` 会在首次启动自动创建。

---

## 3. 启动容器

```bash
docker-compose up -d          # 老版 v1 命令
# 或： docker compose up -d   # v2
docker-compose ps             # 状态应为 Up
```

首次启动 webtop 初始化 `/config` 约 10–30 秒。

---

## 4. 浏览器访问桌面

在**另一台电脑**的浏览器访问（`<IP>` 为运行容器的麒麟机内网 IP，`hostname -I` 可查）：

- **远程访问用 HTTPS**：`https://<IP>:3001`
  - 自签名证书，浏览器会拦：点「高级 → 继续前往 / 仍要访问」。
  - 提示密码时输入 compose 里设的 `PASSWORD`。
- 同机/调试可用 HTTP：`http://localhost:3000`（**不能**用 `http://<远程IP>:3000`——网页客户端要求安全上下文，明文 HTTP + 远程 IP 会被拒，报 `requires a secure connection (HTTPS)`）。

进入后看到 XFCE 桌面（可能背景黑屏、只有一个 X 形光标，这是窗口管理器未起，**不影响 cc-switch 使用**）。

---

## 5. 配置 cc-switch 代理（GUI 内操作）

进桌面后若 cc-switch 窗口没自动出现，**右键桌面 → 打开终端**，执行：

```bash
cc-switch &
```

然后在 cc-switch 窗口里：

1. **添加一个 LLM 后端供应商**（填 Base URL / API Key，即你想让 Claude Code 最终走的那家）。
2. 进入 **代理 / Proxy** 设置，**启用代理**，确认监听端口 **15721**；若有「监听地址」选项，设成 `0.0.0.0`。
3. 选中该供应商为当前路由目标。

---

## 6. 宿主机 Claude Code 接入

在**运行容器的本机**（麒麟机）上，让 Claude Code 经代理路由：

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:15721
# 防止系统代理劫持本地请求：
export NO_PROXY=127.0.0.1,localhost
```

（持久化：写入 `~/.claude/settings.json` 的 `env` 段。）

---

## 7. 验证整条链路

```bash
# 7.1 代理端口在宿主机响应（不能是 Connection refused）
curl -i --max-time 5 http://127.0.0.1:15721

# 7.2 端口监听确认
ss -lnt | grep -E ':(3000|3001|15721)\s'
```

7.3 运行 `claude` 发起一次请求 → 应成功返回，且在 cc-switch GUI 的代理日志/统计里能看到这次转发。

---

## 8. 持久化与重启

- cc-switch 的供应商、API Key、代理设置存于 `/config` 卷（`./cc-switch-data`），**跨容器重建保留**。
- 重建验证：`docker-compose down && docker-compose up -d` → 再次进桌面，配置仍在。
- 容器随 Docker 自启（`restart: unless-stopped`）。确认 Docker 开机自启：
  ```bash
  systemctl is-enabled docker   # 应为 enabled；否则 sudo systemctl enable docker
  ```

---

## 常用运维命令

```bash
docker-compose logs -f cc-switch-webtop      # 跟踪日志
docker-compose restart                        # 重启
docker-compose down                           # 停止并移除容器（保留卷）
docker-compose up -d                          # 重新启动
docker exec -it cc-switch bash                # 进容器排查
```

---

## 已知问题 / 注意事项

- **密码**：默认 `changeme`，部署后**务必**在 compose 改 `PASSWORD` 后 `docker-compose up -d` 重建。
- **cc-switch 不一定自启**：webtop 的 XFCE 会话在容器里有时不完整，cc-switch 窗口可能不会自动出现。兜底：进桌面开终端手动 `cc-switch &`（见第 5 节）。进程随容器存在，但容器重启后需重新拉起一次。
- **黑屏 + X 光标**：窗口管理器未启动的表象，cc-switch 作为唯一窗口仍可正常点击使用。
- **架构限制**：仅 arm64。x86_64 无法运行。
- **收紧暴露面（可选）**：若不再需要内网其他机器直连代理，把 `15721:15721` 改成 `127.0.0.1:15721:15721`，仅本机可达。
- **升级 cc-switch**：需要重新构建镜像（用 Dockerfile + 新 deb），重新 `docker save` 导出新包；不能直接在容器内升级。
