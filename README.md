# mihomo + MetaCubeXD Docker

Run `mihomo` and `MetaCubeXD` with Docker Compose, with scheduled provider refresh.

## Quick Start

```bash
cp .env.example .env
```

Edit `.env` with your subscription values, then run:

```bash
./proxy.sh refresh
./proxy.sh up
```

Open the dashboard:

```text
http://localhost:28080
```

## Commands

```bash
./proxy.sh up           # start services
./proxy.sh stop         # stop services
./proxy.sh down         # remove containers
./proxy.sh refresh      # refresh providers and reload mihomo
./proxy.sh reload       # reload mihomo
./proxy.sh logs         # show compose logs
./proxy.sh ps           # show status
./proxy.sh upgrade      # pull images and recreate services
./proxy.sh clean        # clean unused Docker resources
./proxy.sh reset-cache  # reset mihomo cache.db
```

## Configuration

`.env` example:

```bash
PROVIDER_LIST="equal"
EQUAL_SUB_URL="..."
SUB_UA="ClashforWindows/0.20.39"
```

Optional local fallback config:

```bash
cp scripts/provider-refresh.conf.example scripts/provider-refresh.conf
```

Config priority: runtime environment variables > `.env` > `scripts/provider-refresh.conf`.

## Ports

- MetaCubeXD: `http://localhost:28080`
- mihomo API: `http://localhost:9090`
- mixed proxy: `7990`
- HTTP: `7991`
- SOCKS5: `7992`
- redir: `7993`
- DNS: `1053/udp`

## Scheduled Refresh

`./proxy.sh up` starts `provider-refresh-cron`, which refreshes providers every hour.

```bash
docker logs -f provider-refresh-cron
```

## MetaCubeXD

This config uses `GLOBAL` as the main outbound group. In MetaCubeXD, select nodes from `GLOBAL`.

Reload after config changes:

```bash
./proxy.sh reload
```

## OrbStack

If Reality nodes fail in containers but work on the host client, check the OrbStack network proxy:

```bash
orbctl config set network_proxy none
orbctl stop
orbctl start
```

## Files

- `docker-compose.yml`: service orchestration
- `proxy.sh`: command entrypoint
- `mihomo/config.yaml`: mihomo config
- `scripts/provider-refresh.sh`: provider refresh script
- `scripts/provider-refresh.cron`: scheduled refresh
- `docker/provider-refresh-cron/Dockerfile`: cron container image

## Note

Follow local laws and service terms.
