# cc-switch-container

**Run [cc-switch](https://github.com/farion1231/cc-switch) — a Tauri 2 desktop app for LLM API routing — inside Docker with a browser-accessible remote desktop.**

Control cc-switch's GUI from any computer on your network, while your local CLI tools (Claude Code, etc.) route API requests through cc-switch's proxy port.

> ✅ Works on **both ARM64 and AMD64** architectures.
> ✅ No native GUI session required on the host.
> ✅ Bypass glibc / library compatibility issues on legacy systems.

---

## ✨ Features

- **Browser-based remote desktop** — full XFCE GUI via WebRTC (Selkies/WebCodecs)
- **LLM API proxy** — cc-switch listens on `:15721`, routes to any configured provider
- **Persistent config** — provider settings and API keys survive container restarts
- **Self-contained image** — everything baked into one Docker image, no host dependencies
- **Architecture agnostic** — build for `linux/amd64` or `linux/arm64`

---

## 📋 Prerequisites

- **Docker** (20.10+) with BuildKit support
- **docker-compose** (v1 `docker-compose` or v2 `docker compose`)
- Architecture: **amd64** (x86_64) **or** **arm64** (aarch64)
- Your machine and the browser you'll access it from must be on the **same trusted network** (webtop uses a self-signed HTTPS certificate)
- Disk: ~4 GB free for the image + runtime data

---

## 🚀 Quick Start

### 1. Download cc-switch .deb

Grab the correct `.deb` for your architecture from the [cc-switch releases page](https://github.com/farion1231/cc-switch/releases) and place it in the project directory:

```
cc-switch-container/
├── Dockerfile
├── docker-compose.yml
├── cc-switch.deb          ← you download this
└── README.md
```

> **Naming convention:** The file **must** be named `cc-switch.deb` (the Dockerfile expects this exact name).

### 2. Build the Docker image

```bash
docker compose build
# or: docker-compose build
```

This builds `cc-switch-webtop:local` with webtop (Ubuntu XFCE) + cc-switch installed.

### 3. Edit docker-compose.yml

Open `docker-compose.yml` and **change the `PASSWORD` environment variable** from `changeme` to a strong password — this is your web desktop login.

```yaml
environment:
  - PASSWORD=your-strong-password   # ← CHANGE THIS
```

### 4. Start the container

```bash
docker compose up -d
# or: docker-compose up -d
```

First startup takes 10–30 seconds for webtop to initialize `/config`.

### 5. Access the desktop

From **another computer's browser** (or the same machine):

| URL | When to use |
|---|---|
| `https://<HOST_IP>:3001` | **Remote access** (recommended) |
| `http://localhost:3000` | Local / debugging only |

- Replace `<HOST_IP>` with the container host's LAN IP (`hostname -I`).
- HTTPS uses a self-signed certificate; click through the browser warning ("Advanced → Proceed").
- Enter the `PASSWORD` you set in step 3.

> ⚠️ `http://<REMOTE_IP>:3000` will **not** work — Selkies (the WebRTC client) requires a [secure context](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts). Use HTTPS (`:3001`) for any non-localhost connection.

### 6. Configure cc-switch proxy

Inside the webtop desktop, if cc-switch doesn't appear automatically:

1. Right-click the desktop → **Open Terminal Here**
2. Run: `cc-switch &`

In the cc-switch window:

1. **Add an LLM backend provider** — enter the Base URL and API Key for your LLM service
2. Go to **Proxy settings** → enable the proxy → set port **15721**
3. If there's a "Listen address" option, set it to `0.0.0.0`
4. Select the provider as the active route target

### 7. Connect Claude Code (or any CLI tool)

On the **host machine** (where the container runs):

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:15721
export NO_PROXY=127.0.0.1,localhost
```

To persist, add to `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:15721",
    "NO_PROXY": "127.0.0.1,localhost"
  }
}
```

### 8. Verify end-to-end

```bash
# Proxy is listening
curl -i --max-time 5 http://127.0.0.1:15721

# Ports are bound
ss -lnt | grep -E ':(3000|3001|15721)\s'
```

Then run `claude` (or your LLM CLI) — requests should appear in cc-switch's proxy log.

---

## 🏗️ Architecture

```
┌─────────────────┐   HTTPS :3001    ┌──────────────────────┐
│  Remote Browser │ ────────────────▶│  Webtop (XFCE)       │
│  (Your Laptop)  │                  │  ┌────────────────┐  │
└─────────────────┘                  │  │  cc-switch GUI  │  │
                                     │  └───────┬────────┘  │
                                     └──────────┼───────────┘
                                                │ proxy config
                                                │
                                     ┌──────────▼───────────┐
                                     │  cc-switch Proxy     │
                                     │  (127.0.0.1:15721)   │
                                     └──────────┬───────────┘
                                                │ LLM API calls
                                     ┌──────────▼───────────┐
                                     │  Host CLI (Claude    │
                                     │  Code, curl, etc.)   │
                                     └──────────────────────┘
```

The container runs:
- **linuxserver/webtop** (Ubuntu XFCE) — provides the browser-accessible remote desktop via Selkies (WebRTC)
- **cc-switch** — Tauri 2 desktop app; its GUI runs inside XFCE and its proxy listens on `:15721`

---

## 🔐 Security Notes

| Concern | Mitigation |
|---|---|
| **Web desktop access** | HTTPS on `:3001` with self-signed cert. Change the default `PASSWORD`. |
| **Proxy exposure** | `:15721` binds to `0.0.0.0`. Tighten to `127.0.0.1:15721:15721` if you only need host-local access. |
| **No encryption on proxy** | cc-switch proxies to the upstream LLM via whatever protocol the upstream uses (typically HTTPS). The proxy port itself is plain HTTP — keep it on a trusted network. |
| **Data persistence** | API keys and provider config are stored in the `./cc-switch-data` volume. Protect this directory. |

---

## 🛠️ Maintenance

```bash
# View logs
docker compose logs -f

# Restart container
docker compose restart

# Rebuild after cc-switch update (download new .deb first)
docker compose build --no-cache
docker compose up -d

# Stop & remove container (data volume preserved)
docker compose down

# Enter container for troubleshooting
docker exec -it cc-switch bash
```

---

## ⚠️ Known Issues

| Issue | Workaround |
|---|---|
| **cc-switch doesn't auto-start** | The webtop XFCE session may be incomplete. **Fix:** Right-click desktop → Terminal → `cc-switch &` |
| **Black screen + X cursor only** | Window manager didn't start. cc-switch window still works normally. |
| **Upgrades require rebuild** | cc-switch is baked into the image. Download new `.deb`, re-run `docker compose build --no-cache`, then `up -d`. |

---

## ❓ FAQ

**Q: Can I run this on x86_64?**  
Yes. The Dockerfile builds on any architecture that `lscr.io/linuxserver/webtop:ubuntu-xfce` supports (both amd64 and arm64).

**Q: Do I need a GPU?**  
No. Webtop uses software rendering. The desktop may feel slow but is perfectly usable for configuring cc-switch.

**Q: Can I use this with tools other than Claude Code?**  
Absolutely. Any HTTP client can point its base URL to `http://<host>:15721`. cc-switch handles routing to whichever LLM provider you've configured.

**Q: How do I update cc-switch?**  
Download the new `.deb`, rebuild the image with `docker compose build --no-cache`, then restart: `docker compose up -d`.

---

## 📄 License

MIT
