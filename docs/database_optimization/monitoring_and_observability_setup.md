# Monitoring and Observability Setup - Patchwork Dashboard

This is the canonical monitoring and observability guide for Patchwork Dashboard.

Use this document as the single source of truth for implementation and keep the local monitoring stack aligned to the current Rails app configuration.

## Scope and compatibility

This setup is aligned with Mastodon observability patterns and adapted to current Patchwork Dashboard conventions.

What this means in practice:

- Prometheus exporter environment variable names follow Mastodon conventions (`MASTODON_PROMETHEUS_EXPORTER_*`).
- OpenTelemetry setup follows Mastodon initializer patterns.
- Patchwork-specific docker networking, health checks, and baseline benchmarking remain compatible with this repository.

## Architecture

The stack has two complementary layers:

- Metrics: Prometheus Exporter -> Prometheus -> Grafana
- Traces (optional): OpenTelemetry SDK -> OTel Collector -> Jaeger/Tempo

## Part 1 - Application-side changes

### 1.1 Structured logs

`lograge` is enabled as a production logging option when `LOGRAGE_ENABLED=true`. This keeps request logs concise and structured while preserving the repo’s existing Prometheus exporter instrumentation.

Reference initializer:

- [../../config/initializers/lograge.rb](../../config/initializers/lograge.rb)

### 1.2 Prometheus exporter (recommended baseline)

Add to Gemfile:

```ruby
gem 'prometheus_exporter', '~> 2.2', require: false
```

Use a single initializer path:

- `config/initializers/prometheus_exporter.rb`

Do not create both `prometheus.rb` and `prometheus_exporter.rb`; pick one canonical initializer (`prometheus_exporter.rb`).

Suggested initializer behavior:

- Enable only when `MASTODON_PROMETHEUS_EXPORTER_ENABLED=true`.
- Support local mode (`MASTODON_PROMETHEUS_EXPORTER_LOCAL=true`) for one-process development.
- Enable request middleware only when `MASTODON_PROMETHEUS_EXPORTER_WEB_DETAILED_METRICS=true`.

### 1.3 Sidekiq instrumentation

Integrate Prometheus exporter instrumentation inside existing Sidekiq server configuration.

Reference:

- [../../config/initializers/sidekiq.rb](../../config/initializers/sidekiq.rb)

Important local rule:

- When running both web and Sidekiq in local mode, avoid binding multiple in-process exporter servers to the same host/port.
- Prefer a dedicated exporter process/container for multi-process development.

### 1.4 OpenTelemetry tracing (optional)

Add OTel gems only when you are ready to run traces:

```ruby
gem 'opentelemetry-api', '~> 1.11.0'

group :opentelemetry do
  gem 'opentelemetry-exporter-otlp', '~> 0.34.0', require: false
  gem 'opentelemetry-instrumentation-active_job', '~> 0.13.0', require: false
  gem 'opentelemetry-instrumentation-concurrent_ruby', '~> 0.25.0', require: false
  gem 'opentelemetry-instrumentation-faraday', '~> 0.33.0', require: false
  gem 'opentelemetry-instrumentation-net_http', '~> 0.29.0', require: false
  gem 'opentelemetry-instrumentation-pg', '~> 0.37.0', require: false
  gem 'opentelemetry-instrumentation-rack', '~> 0.31.0', require: false
  gem 'opentelemetry-instrumentation-rails', '~> 0.42.0', require: false
  gem 'opentelemetry-instrumentation-redis', '~> 0.29.0', require: false
  gem 'opentelemetry-instrumentation-sidekiq', '~> 0.29.0', require: false
  gem 'opentelemetry-sdk', '~> 1.4', require: false
end
```

Use `config/initializers/opentelemetry.rb`.

Compatibility note for this repo:

- Exclude health probes based on current route usage (`/health_check` in this repository), and optionally `/metrics`.

## Part 2 - Environment variables

Add to `.env` and `.env.sample` when implementing:

```bash
# OpenTelemetry (optional)
OTEL_EXPORTER_OTLP_ENDPOINT=
OTEL_SERVICE_NAME_PREFIX=patchwork
OTEL_SERVICE_NAME_SEPARATOR=/

# Prometheus exporter
MASTODON_PROMETHEUS_EXPORTER_ENABLED=true
MASTODON_PROMETHEUS_EXPORTER_LOCAL=false
MASTODON_PROMETHEUS_EXPORTER_HOST=localhost
MASTODON_PROMETHEUS_EXPORTER_PORT=9394
MASTODON_PROMETHEUS_EXPORTER_WEB_DETAILED_METRICS=true
MASTODON_PROMETHEUS_EXPORTER_SIDEKIQ_DETAILED_METRICS=true
```

## Part 3 - Local monitoring stack

There are two valid local approaches:

1. Existing database optimization example stack

- [monitoring/examples/docker-compose.monitoring.yml](monitoring/examples/docker-compose.monitoring.yml)
- [monitoring/examples/prometheus.yml](monitoring/examples/prometheus.yml)

2. Extended observability stack (if traces are enabled)

- Add OTel collector and Jaeger/Tempo to the monitoring compose.

Repository compatibility rules:

- Use `patchwork_network` and `mastodon_internal_network` conventions from [../../docker-compose.yml](../../docker-compose.yml).
- Avoid introducing a new external network name unless you document migration clearly.

## Part 4 - AWS deployment guidance

Recommended production shape:

- Keep monitoring services private (internal SG/VPC scope).
- Run Prometheus/Grafana with persistent storage.
- Use read-only database users for PgHero/postgres_exporter.
- Keep `/metrics` non-public.

## Part 5 - Benchmarking and validation

Current baseline command in this repository:

```bash
bundle exec rake db:analyze_baseline
```

For quick request-level validation, this repo also includes a lightweight public benchmark endpoint:

```bash
curl "http://localhost:3000/monitoring/benchmark?iterations=10"
```

This endpoint returns a minimal JSON payload with timing metadata (`ok`, `iterations`, `elapsed_seconds`) and is intended for local validation of request latency and dashboard wiring. The route is intentionally safelisted from Rack::Attack in local/testing environments so it remains reachable without triggering the normal API rate limiter.

Reference task:

- [../../lib/tasks/analyze_baseline.rake](../../lib/tasks/analyze_baseline.rake)
- [../../app/controllers/monitoring_controller.rb](../../app/controllers/monitoring_controller.rb)

If adding a new benchmark task later (for example `performance:benchmark`), treat it as optional and document why both are needed.

## Implementation checklist

- [ ] Add/verify gems (`prometheus_exporter`, optional OTel gems)
- [ ] Create `config/initializers/prometheus_exporter.rb`
- [ ] Extend [../../config/initializers/sidekiq.rb](../../config/initializers/sidekiq.rb) with exporter instrumentation
- [ ] Optionally create `config/initializers/opentelemetry.rb`
- [ ] Add env vars to `.env` and `.env.sample`
- [ ] Validate local scraping and dashboards
- [ ] Run `bundle exec rake db:analyze_baseline` before/after major DB optimizations

## Verification checklist

- [ ] `/metrics` endpoint is reachable from Prometheus, not public internet
- [ ] Grafana shows request latency, throughput, and DB metrics
- [ ] Sidekiq metrics are present when enabled
- [ ] Health probes do not create trace noise
- [ ] No duplicate exporter middleware/instrumentation paths are active
- [ ] Only this file is used as observability source of truth
