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
The top-level outbound entry is `proxy-groups.GLOBAL` in `mihomo/config.yaml`.

This deployment runs `mihomo` in `global` mode. All client traffic goes through
the `GLOBAL` group, and `GLOBAL` selects directly from the `equal` provider.
Subscription nodes are not filtered or hidden from the Web UI, and `DIRECT` is
not added as a local choice.

Recommended setup in MetaCubeXD:
1. Open `http://localhost:28080`
2. Use the `GLOBAL` group as the only normal outbound group
3. If a node has Reality authentication failures in Docker but works on the host, check the Docker runtime network path instead of changing the subscription

Apply config changes with:
```bash
./proxy.sh reload
```

## UDP Stability Notes
This setup publishes UDP ports explicitly instead of relying on Docker host networking:
- Use `7992/udp` for SOCKS5 UDP associate clients.
- Use `1053/udp` for DNS clients.
- DNS upstreams use DoH, so clients can keep using UDP to this host while `mihomo` resolves through HTTPS upstreams.
- `mihomo` runs in `global` mode, so client traffic uses the selected/tested proxy node instead of local direct rules.
- Runtime IPv6 is disabled to avoid clients preferring IPv6 destinations when the Docker deployment and provider nodes are primarily IPv4-oriented.

If `7992/udp` accepts SOCKS5 UDP associate but external UDP requests still time out, check MetaCubeXD or the controller API for `GLOBAL` health. When `GLOBAL` health fails with `REALITY authentication failed`, check the Docker runtime network path before changing the subscription.

### OrbStack Network Proxy
This project is currently running on OrbStack. OrbStack's `network_proxy=auto`
can transparently send container egress through a different proxy path than the
macOS host. Reality nodes may reject that path even when the same subscription
works in Clash Verge Rev on the host.

Use a direct OrbStack container egress path:
```bash
orbctl config set network_proxy none
orbctl stop
orbctl start
```

Verify the fix:
```bash
docker info | grep -i 'HTTP Proxy'
docker run --rm curlimages/curl:8.10.1 https://checkip.amazonaws.com
curl --socks5-hostname 127.0.0.1:7992 https://cp.cloudflare.com/generate_204 -I
```

## Mihomo Core Version
This compose file pins `metacubex/mihomo:v1.19.25` to match the Mihomo core
bundled by Clash Verge Rev 2.5.1 on this machine. If Reality nodes still fail
with this core version, compare the Docker runtime network path with the working
desktop client before changing or hiding subscription nodes.

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
