# Newsmast Dashboard Docker installation

This is the canonical Docker Compose procedure for the Patchwork Dashboard repository. The Compose service is named `app`; use that name in `docker compose` commands.

## Prerequisites

- Docker Engine and Docker Compose v2.
- A running Mastodon deployment, including reachable PostgreSQL and Redis.
- A Docker network named `mastodon_internal_network`, or a Compose-file change that connects `app` to the correct network.
- Mastodon application credentials with the scopes listed in `.env.sample`.

## Configure the deployment

```bash
git clone https://github.com/patchwork-hub/patchwork_dashboard.git
cd patchwork_dashboard
cp .env.sample .env
chmod 600 .env
```

Set the required Mastodon, PostgreSQL, Redis, administrator, and Rails secret values in `.env`. Set `EXTERNAL_PORT` to the host port to publish; the container listens on port `3001`. Do not commit `.env` or reuse its placeholder secrets.

The default Compose file pulls `newsmast/patchwork_dashboard:latest`; it does not contain a `build:` definition. `docker compose up -d --build` is therefore unnecessary unless you add one locally.

## Start and initialize

```bash
docker compose pull
docker compose up -d
docker compose ps
docker compose logs app
docker compose exec app bundle exec rails db:migrate
docker compose exec app bundle exec rails db:seed
```

Seeding creates initial application data, including the configured master administrator where supported by the application. Open the Dashboard at the externally published URL and sign in with the configured master-administrator credentials.

The container health check calls `http://localhost:${EXTERNAL_PORT}/health_check`. Because the application itself listens on `3001`, keep `EXTERNAL_PORT=3001` unless you have validated a Compose override that makes the health check use the container port.

## Operations

```bash
docker compose exec app bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SELECT 1').first"
curl http://localhost:3001/health_check
docker compose logs -f app
```

To update the image:

```bash
docker compose pull
docker compose up -d
docker compose exec app bundle exec rails db:migrate
```

The Compose file persists Dashboard storage, public system files, and logs in the `patchwork_storage`, `patchwork_public`, and `patchwork_logs` volumes. It does not back up the shared Mastodon PostgreSQL database or Redis. Back up those systems with the Mastodon deployment's documented tooling; test restore procedures before relying on volume archives.

## Production security

Terminate TLS at a reverse proxy, limit published ports and database/Redis network access, and protect `.env` with restrictive file permissions. Rotate `STATIC_TOKEN`, `SECRET_KEY_BASE`, Mastodon credentials, object-storage keys, DNS credentials, and Patchwork Hub API credentials according to your operational policy. Never place secrets in logs, issue reports, or documentation.

## Troubleshooting

Use `docker compose logs app` first. Connection errors normally indicate inaccessible shared PostgreSQL/Redis services or incorrect `.env` values. See [docs/troubleshooting/common-issues.md](docs/troubleshooting/common-issues.md) for the verified diagnostic paths.