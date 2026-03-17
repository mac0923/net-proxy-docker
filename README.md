# mihomo + MetaCubeXD (Docker Setup)

This project runs `mihomo` (Clash.Meta core) and the `MetaCubeXD` dashboard with Docker Compose, and supports both manual and scheduled provider refresh.

It is compatible with OrbStack:
- scripts auto-detect `docker compose` and standalone `docker-compose`
- scheduled refresh reloads `mihomo` through the controller API instead of mounting the host Docker socket
- `mihomo` now runs with `network_mode: host`, while MetaCubeXD keeps `28080` as the dashboard entry

## Quick Start
1. Prepare environment variables:
   ```bash
   cp .env.example .env
   ```
2. Update `.env` with your own subscription values.
3. Start services:
   ```bash
   ./proxy-up.sh
   ```
4. Open the dashboard and verify everything is running.

If you use OrbStack, make sure OrbStack is already running before executing the scripts.

## Endpoints and Ports
- Dashboard (MetaCubeXD): `http://localhost:28080`
- mihomo API: `http://localhost:9090` (requires `secret`, exposed by host network mode)
- Proxy ports (from `mihomo/config.yaml`, exposed by host network mode):
  - mixed: `7990`
  - http: `7991`
  - socks5: `7992`
  - redir: `7993`

## Common Scripts
- `./proxy-up.sh`: start all services
- `./proxy-stop.sh`: stop services (keep containers)
- `./proxy-down.sh`: stop and remove containers
- `./proxy-clean.sh`: prune stopped containers, unused images, and build cache without touching running services
- `./proxy-reset-cache.sh`: back up and remove `mihomo/cache.db`, then recreate the `mihomo` container
- `./proxy-reload.sh`: restart `mihomo` to reload config
- `./proxy-refresh.sh`: refresh provider files by list and reload `mihomo`
- `./proxy-refresh-manual.sh`: trigger an immediate one-time refresh
- `./proxy-upgrade.sh`: pull newer images and recreate services

## Upgrade Images
Run:
```bash
./proxy-upgrade.sh
```

The script does the following:
1. Pull the image versions declared in `docker-compose.yml` (`mihomo`, `metacubexd`).
2. Rebuild local `provider-refresh-cron` image with latest base image.
3. Run `up -d` to recreate services with updated images.

## Cleanup Docker Resources
Run:
```bash
./proxy-clean.sh
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
PROVIDER_LIST="qyt,equal"
QYT_SUB_URL="..."
EQUAL_SUB_URL="..."
SUB_UA="ClashforWindows/0.20.39"
```

Variable priority (per variable):
1. Runtime environment variable
2. Project root `.env`
3. `scripts/provider-refresh.conf`

Compatibility note:
- `qyt` still supports legacy `SUB_URL` (recommended to migrate to `QYT_SUB_URL`).

## Scheduled Refresh
`./proxy-up.sh` also starts `provider-refresh-cron` for automatic refresh.

- Cron file: `scripts/provider-refresh.cron`
- Default schedule: `0 * * * * /workspace/scripts/provider-refresh.sh`
- Logs:
  ```bash
  docker logs -f provider-refresh-cron
  ```

## Change Default Provider
The top-level outbound entry is `proxy-groups.PROXY` in `mihomo/config.yaml`.

Available choices now:
- `EQUAL`: direct single-hop via the `equal` provider
- `QYT`: direct single-hop via the `qyt` provider
- `EQUAL-VIA-QYT`: chain mode, use `equal` nodes as the exit hop and `QYT` as the dialer hop
- `QYT-VIA-EQUAL`: chain mode, use `qyt` nodes as the exit hop and `EQUAL` as the dialer hop

Recommended chain setup in MetaCubeXD:
1. Open `http://localhost:28080`
2. In group `QYT`, pick the first-hop node you want to use
3. In group `EQUAL`, pick the first-hop node you want to use when using `QYT-VIA-EQUAL`
4. In group `PROXY`, switch to either `EQUAL-VIA-QYT` or `QYT-VIA-EQUAL`
5. Inside that chained group, pick the second-hop exit node

The chained providers are implemented with `dialer-proxy`, so each node in the chained view will establish its connection through the corresponding first-hop group.

If you want to force a direct single-hop default in config, keep only the direct groups in `PROXY`:
```yaml
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - EQUAL
      - QYT
      - DIRECT
```

Apply config changes with:
```bash
./proxy-reload.sh
```

## Repository Layout
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
