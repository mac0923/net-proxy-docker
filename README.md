# mihomo + MetaCubeXD (Docker Setup)

This project runs `mihomo` (Clash.Meta core) and the `MetaCubeXD` dashboard with Docker Compose, and supports both manual and scheduled provider refresh.

It is compatible with OrbStack:
- scripts auto-detect `docker compose` and standalone `docker-compose`
- scheduled refresh reloads `mihomo` through the controller API instead of mounting the host Docker socket
- `mihomo` uses normal bridge networking with explicit TCP/UDP port publishing, while MetaCubeXD keeps `28080` as the dashboard entry

## Quick Start
1. Prepare environment variables:
   ```bash
   cp .env.example .env
   ```
2. Update `.env` with your own subscription values.
3. Refresh provider files once:
   ```bash
   ./proxy.sh refresh
   ```
4. Start services:
   ```bash
   ./proxy.sh up
   ```
5. Open the dashboard and verify everything is running.

If you use OrbStack, make sure OrbStack is already running before executing the scripts.

## Endpoints and Ports
- Dashboard (MetaCubeXD): `http://localhost:28080`
- mihomo API: `http://localhost:9090` (requires `secret`, published only on `127.0.0.1`)
- Proxy ports (from `mihomo/config.yaml`, explicitly published by Compose):
  - mixed: `7990/tcp`, `7990/udp`
  - http: `7991/tcp`
  - socks5: `7992/tcp`, `7992/udp`
  - redir: `7993/tcp`, `7993/udp`
  - DNS: `1053/udp`

## Common Commands
All container operations use one entrypoint:
```bash
./proxy.sh <command>
```

- `./proxy.sh up`: start all services
- `./proxy.sh stop`: stop services without removing containers
- `./proxy.sh down`: stop and remove containers
- `./proxy.sh clean`: prune stopped containers, unused images, and build cache without touching running services
- `./proxy.sh reset-cache`: back up and remove `mihomo/cache.db`, then recreate the `mihomo` container
- `./proxy.sh reload`: restart `mihomo` to reload config
- `./proxy.sh refresh`: refresh provider files by list and reload `mihomo`
- `./proxy.sh upgrade`: pull newer images and recreate services
- `./proxy.sh ps`: show Compose service status
- `./proxy.sh logs`: follow Compose logs

## Upgrade Images
Run:
```bash
./proxy.sh upgrade
```

The script does the following:
1. Pull the image versions declared in `docker-compose.yml` (`mihomo`, `metacubexd`).
2. Rebuild local `provider-refresh-cron` image with the pinned base image.
3. Run `up -d` to recreate services with updated images.

## Cleanup Docker Resources
Run:
```bash
./proxy.sh clean
```

The script does the following:
1. Remove stopped containers.
2. Remove unused images.
3. Remove unused build cache.

Note:
- The script does not stop running containers.
- The script does not remove Docker volumes.

## Provider Refresh Configuration
`scripts/provider-refresh.sh` supports list-based provider refresh. To add a provider, only configuration changes are needed.

If you want to keep local private config without committing secrets, use the template file:
```bash
cp scripts/provider-refresh.conf.example scripts/provider-refresh.conf
```

Recommended `.env` values:
```bash
PROVIDER_LIST="equal"
EQUAL_SUB_URL="..."
SUB_UA="ClashforWindows/0.20.39"
```

Variable priority (per variable):
1. Runtime environment variable
2. Project root `.env`
3. `scripts/provider-refresh.conf`

Compatibility note:
- If `scripts/provider-refresh.conf` exists, make sure its `PROVIDER_LIST` also includes every provider you want refreshed, for example `PROVIDER_LIST="equal"`.

## Scheduled Refresh
`./proxy.sh up` also starts `provider-refresh-cron` for automatic refresh.

- Cron file: `scripts/provider-refresh.cron`
- Default schedule: `0 * * * * /workspace/scripts/provider-refresh.sh`
- Logs:
  ```bash
  docker logs -f provider-refresh-cron
  ```

## Change Default Provider
The top-level outbound entry is `proxy-groups.PROXY` in `mihomo/config.yaml`.

Available choices now:
- `AUTO`: fallback mode via the `equal` provider; this is the recommended stable default
- `MANUAL`: direct manual selection via the `equal` provider
- `DIRECT`: bypass proxy

Recommended setup in MetaCubeXD:
1. Open `http://localhost:28080`
2. Keep group `PROXY` on `AUTO` for normal use
3. Use `MANUAL` only when you need to pin a specific node temporarily

If you want to force a direct single-hop default in config, keep only the direct groups in `PROXY`:
```yaml
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - AUTO
      - MANUAL
      - DIRECT
```

Apply config changes with:
```bash
./proxy.sh reload
```

## UDP Stability Notes
This setup publishes UDP ports explicitly instead of relying on Docker host networking:
- Use `7992/udp` for SOCKS5 UDP associate clients.
- Use `1053/udp` for DNS clients.
- DNS upstreams use DoH, so clients can keep using UDP to this host while `mihomo` resolves through HTTPS upstreams.

If `7992/udp` accepts SOCKS5 UDP associate but external UDP requests still time out, check MetaCubeXD or the controller API for `AUTO` health. When all provider nodes are unhealthy, no Docker-side configuration can make proxied UDP work; refresh or replace the subscription first.

## Repository Layout
- `proxy.sh`: single command entrypoint for container operations
- `docker-compose.yml`: container orchestration
- `scripts/compose.sh`: Compose compatibility wrapper for `docker compose` / `docker-compose`
- `mihomo/config.yaml`: mihomo core config (ports, rules, provider references)
- `scripts/provider-refresh.sh`: provider refresh script
- `scripts/provider-refresh.conf`: local fallback config
- `scripts/provider-refresh.cron`: refresh schedule
- `docker/provider-refresh-cron/Dockerfile`: cron container image
- `.env.example`: environment template

## Compliance
This project is for legal and legitimate use only. Follow local laws and service terms.
