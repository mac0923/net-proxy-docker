# mihomo + MetaCubeXD (Docker Setup)

This project runs `mihomo` (Clash.Meta core) and the `MetaCubeXD` dashboard with `docker compose`, and supports both manual and scheduled provider refresh.

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

## Endpoints and Ports
- Dashboard (MetaCubeXD): `http://localhost:8080`
- mihomo API: `http://localhost:9090` (requires `secret`)
- Proxy ports (from `mihomo/config.yaml`):
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
- `./proxy-refresh.sh`: refresh provider files by list and restart `mihomo`
- `./proxy-refresh-manual.sh`: trigger an immediate one-time refresh
- `./proxy-upgrade.sh`: pull newer images and recreate services

## Upgrade Images
Run:
```bash
./proxy-upgrade.sh
```

The script does the following:
1. Pull latest remote images (`mihomo`, `metacubexd`).
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
`docker compose up -d` also starts `provider-refresh-cron` for automatic refresh.

- Cron file: `scripts/provider-refresh.cron`
- Default schedule: `0 * * * * /workspace/scripts/provider-refresh.sh`
- Logs:
  ```bash
  docker logs -f provider-refresh-cron
  ```

## Change Default Provider
The default provider is controlled by `proxy-groups.PROXY.use` in `mihomo/config.yaml`.

Example (use only `equal`):
```yaml
proxy-groups:
  - name: "PROXY"
    type: select
    use:
      - equal
```

Then apply changes:
```bash
./proxy-reload.sh
```

## Repository Layout
- `docker-compose.yml`: container orchestration
- `mihomo/config.yaml`: mihomo core config (ports, rules, provider references)
- `scripts/provider-refresh.sh`: provider refresh script
- `scripts/provider-refresh.conf`: local fallback config
- `scripts/provider-refresh.cron`: refresh schedule
- `docker/provider-refresh-cron/Dockerfile`: cron container image
- `.env.example`: environment template

## Compliance
This project is for legal and legitimate use only. Follow local laws and service terms.
