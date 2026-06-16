# cc-switch-container: Dockerized Webtop Remote Desktop for LLM API Routing

Run [cc-switch](https://github.com/farion1231/cc-switch) (Tauri 2 desktop tool for LLM API routing) in a Docker container with **browser-based remote desktop**. Access its GUI from any computer on your network while your local Claude Code routes API requests through cc-switch's **proxy port 15721**.

> **Primary use case**: Run cc-switch on legacy ARM64 systems with older glibc versions (e.g., KylinOS with glibc 2.31) where the native cc-switch binary won't run. Webtop remote desktop solves the "no local GUI session" limitation.

## 🚀 Quick Start

**Prerequisites:**
- ARM64/aarch64 architecture only (`uname -m` = aarch64)
- Docker and docker-compose installed
- User in docker group
- Trusted internal network (self-signed certificate for HTTPS)

```bash
# 1. Import the pre-built image (1.2GB compressed, auto-expands to ~3.5GB)
sha256sum -c cc-switch-webtop.local.tar.gz.sha256
docker load -i cc-switch-webtop.local.tar.gz

# 2. Configure docker-compose.yml (edit PASSWORD!)
version: "3.7"
services:
  cc-switch-webtop:
    image: cc-switch-webtop:local
    container_name: cc-switch
    environment:
      - PUID=1000
      - PGID=1000
      - PASSWORD=your-strong-password  # EDIT THIS!
      - WEBKIT_DISABLE_COMPOSITING_MODE=1
    volumes:
      - ./cc-switch-data:/config
    ports:
      - "3000:3000"    # HTTP (localhost only)
      - "3001:3001"    # HTTPS (remote access)
      - "15721:15721"  # cc-switch proxy
    shm_size: "1gb"
    restart: unless-stopped

# 3. Start container
docker-compose up -d

# 4. Access via browser: https://<SERVER_IP>:3001
# 5. Inside webtop: Launch cc-switch & configure proxy (0.0.0.0:15721)
# 6. On host: export ANTHROPIC_BASE_URL=http://127.0.0.1:15721
```

## 🎯 What Problem This Solves

### Scenario
You have:
- An ARM64 server (e.g., KylinOS) with limited glibc support (2.31)
- Need to run cc-switch for LLM API routing
- No local GUI environment on the server
- Want to control cc-switch from another computer

### Solution
- **Container isolation**: Bypass glibc compatibility issues
- **Remote web desktop**: Access GUI from any browser
- **API proxy**: Route Claude Code requests through cc-switch
- **Zero native dependencies**: Everything runs inside Docker

## 📦 Artifacts

| File | Description |
|------|-------------|
| `cc-switch-webtop.local.tar.gz` | Pre-built image (1.2GB compressed) |
| `.sha256` | Checksum for integrity verification |
| `docker-compose.yml` | Runtime configuration template |
| `Dockerfile` | Build from source (optional) |

**Image details:** `cc-switch-webtop:local` (ARM64/Linux), ~3.5GB expanded

## 🔧 Architecture

```
┌─────────────────┐    HTTPS:3001    ┌─────────────────┐
│ Remote Browser  │ ────────────────▶│   Webtop GUI    │
│ (Your Laptop)   │                  │ (XFCE Desktop)  │
└─────────────────┘ ◀─────────────── └─────────────────┘
                             │
                             │ cc-switch GUI Configuration
                             │
                     ┌───────▼───────┐    HTTP:15721    ┌─────────────────┐
                     │ cc-switch     │ ────────────────▶│   Host System   │
                     │ Proxy Server  │                  │ (Claude Code)   │
                     └───────────────┘ ◀─────────────── └─────────────────┘
                             │
                             │ LLM API Calls
                             │
                     ┌───────▼───────┐
                     │ LLM Providers │
                     │ (OpenAI, etc.)│
                     └───────────────┘
```

## 🔐 Security Notes

- **Webtop access**: Always use HTTPS (`:3001`) for remote access
- **Local access**: HTTP (`:3000`) only works from `localhost`
- **Password**: Default `changeme` - **MUST be changed** in production
- **Network exposure**: Proxy port `15721` binds to `0.0.0.0` (internal network only)

## ⚠️ Known Issues & Limitations

- **ARM64 only**: Image built for aarch64, won't run on x86_64
- **Auto-start unreliable**: cc-switch may not start automatically - use fallback: `cc-switch &`
- **Black screen**: XFCE window manager may not fully load (cc-switch window still works)
- **Upgrades**: Rebuild image required for cc-switch version updates

## 📚 Related Projects

- [cc-switch](https://github.com/farion1231/cc-switch) - Tauri 2 desktop app for LLM API routing
- [linuxserver/webtop](https://github.com/linuxserver/docker-webtop) - Base Docker image
- [Selkies](https://github.com/selkies-project/selkies) - WebRTC remote desktop backend

## 🆘 Troubleshooting

```bash
# Check container status
docker-compose ps
docker-compose logs -f

# Access container shell
docker exec -it cc-switch bash

# Verify proxy connectivity
curl -i --max-time 5 http://127.0.0.1:15721

# Check port bindings
ss -lnt | grep -E ':(3000|3001|15721)'
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Built for developers who need LLM API routing on constrained ARM64 environments.**
