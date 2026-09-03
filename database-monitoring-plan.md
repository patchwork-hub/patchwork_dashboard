# Patchwork Dashboard — Database Monitoring & APM Implementation Plan

> **Branch:** `database-optimization`  
> **Goal:** Detect intensive, slow queries and map which APIs hit the database heavily.  
> **Environment:** Local development first, then production.  
> **Compatibility:** Mastodon (Rails) + custom Patchwork Dashboard tables (`channels`, etc.)

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Tool Selection & Rationale](#2-tool-selection--rationale)
3. [Architecture Overview](#3-architecture-overview)
4. [Phase 1: PgHero (PostgreSQL Insights)](#4-phase-1-pghero-postgresql-insights)
5. [Phase 2: OpenTelemetry + Jaeger (Distributed Tracing)](#5-phase-2-opentelemetry--jaeger-distributed-tracing)
6. [Phase 3: Prometheus + Grafana (Metrics & Dashboards)](#6-phase-3-prometheus--grafana-metrics--dashboards)
7. [Local Development Docker Compose (Optional)](#7-local-development-docker-compose-optional)
8. [Production Migration Notes](#8-production-migration-notes)
9. [Mastodon Compatibility Checklist](#9-mastodon-compatibility-checklist)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Current State Assessment

### What Exists Today

| Tool                       | Environment                | Purpose                                               | Production Ready?    |
| -------------------------- | -------------------------- | ----------------------------------------------------- | -------------------- |
| `rack-mini-profiler`       | `development` only         | Request profiling, SQL timing                         | ❌ No                |
| `stackprof` + `flamegraph` | `development` only         | Call-stack flamegraphs                                | ❌ No                |
| `bullet` gem               | `development` only         | N+1 query detection                                   | ❌ No                |
| `BulletLogger` middleware  | `development`/`local` only | Logs N+1 warnings to HTTP header                      | ❌ No                |
| `QueryProfiler` middleware | `development`/`local` only | Returns all SQL + durations in `X-SQL-Profile` header | ❌ No                |
| `health_check` gem         | All environments           | Basic liveness probe (`/health_check`)                | ✅ Yes (but minimal) |

### What's Missing in Production

- ❌ No query performance data persistence
- ❌ No correlation between API endpoints and SQL queries
- ❌ No time-series metrics for resource trends
- ❌ No alerting on slow queries or DB overload
- ❌ No visibility into custom `channels` table performance

> **Security Note:** `QueryProfiler` and `BulletLogger` must **never** be enabled in production. They leak SQL details in HTTP headers and create unbounded memory growth per request.

---

## 2. Tool Selection & Rationale

| Tool              | Role                             | Answers PM Question                                                                 |
| ----------------- | -------------------------------- | ----------------------------------------------------------------------------------- |
| **PgHero**        | PostgreSQL performance dashboard | "Which queries consume the most total DB time?" "Which tables are missing indexes?" |
| **OpenTelemetry** | Distributed tracing (API → DB)   | "Which API endpoint triggers which expensive query?"                                |
| **Jaeger**        | Trace visualization UI           | "Show me the waterfall of a slow request."                                          |
| **Prometheus**    | Time-series metrics collector    | "What's the trend of DB connection pool usage over time?"                           |
| **Grafana**       | Metrics dashboard & alerting     | "Alert me when API p95 latency exceeds 500ms."                                      |

### Why Not Just Prometheus + Grafana?

Prometheus + Grafana are **infrastructure metrics** tools. They tell you _that_ your database is slow, but not _which API caused it_ or _what the SQL looks like_. You need **PgHero** for query-level PostgreSQL insights and **OpenTelemetry** for request-to-query causality.

---

## 3. Architecture Overview

### Local Development (In-App + Docker Sidecars)

```
┌─────────────────────────────────────────────────────────────────┐
│  Your Laptop                                                    │
│                                                                 │
│  ┌─────────────────────────┐    ┌──────────────────────────┐   │
│  │  Rails Server           │    │  Docker Compose          │   │
│  │  (patchwork_dashboard)  │    │                          │   │
│  │                         │    │  ┌────────────────────┐  │   │
│  │  • PgHero mounted at    │◄──►│  │  Jaeger (traces)   │  │   │
│  │    /pghero              │    │  │  :16686            │  │   │
│  │                         │    │  └────────────────────┘  │   │
│  │  • OpenTelemetry SDK    │───►│  ┌────────────────────┐  │   │
│  │    (sends traces)       │    │  │  Prometheus        │  │   │
│  │                         │    │  │  :9090             │  │   │
│  │  • prometheus_exporter  │◄──►│  └────────────────────┘  │   │
│  │    (exposes metrics)    │    │  ┌────────────────────┐  │   │
│  │                         │    │  │  Grafana           │  │   │
│  │  • Devise auth for      │    │  │  :3000             │  │   │
│  │    /pghero              │    │  └────────────────────┘  │   │
│  └─────────────────────────┘    └──────────────────────────┘   │
│           │                                                     │
│           ▼                                                     │
│  ┌─────────────────────────┐                                    │
│  │  PostgreSQL (local)     │                                    │
│  │  • pg_stat_statements   │                                    │
│  │  • Mastodon DB          │                                    │
│  │  • Custom tables        │                                    │
│  └─────────────────────────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Production (Recommended)

```
┌─────────────────────────────────────────────────────────────────┐
│  Production Cluster                                             │
│                                                                 │
│  ┌─────────────────────────┐    ┌──────────────────────────┐   │
│  │  Rails App (Dashboard)  │    │  Monitoring Stack        │   │
│  │                         │    │  (separate containers)   │   │
│  │  • OpenTelemetry SDK    │───►│  • OTel Collector        │   │
│  │  • prometheus_exporter  │◄──►│  • Jaeger / Tempo        │   │
│  │                         │    │  • Prometheus            │   │
│  └─────────────────────────┘    │  • Grafana               │   │
│           │                     │  • Alertmanager          │   │
│           ▼                     └──────────────────────────┘   │
│  ┌─────────────────────────┐                                    │
│  │  PostgreSQL             │◄───┐                               │
│  │  • pg_stat_statements   │    │                               │
│  └─────────────────────────┘    │                               │
│           ▲                     │                               │
│           │                     │                               │
│  ┌─────────────────────────┐    │                               │
│  │  PgHero (Docker)        │────┘                               │
│  │  • Separate container   │                                    │
│  │  • No app coupling      │                                    │
│  └─────────────────────────┘                                    │
└─────────────────────────────────────────────────────────────────┘
```

> **Local vs Production PgHero:** In local dev, mount PgHero inside your Rails app for convenience. In production, run it as a separate Docker container to avoid PgHero's diagnostic queries competing with user traffic for DB connections.

---

## 4. Phase 1: PgHero (PostgreSQL Insights)

**Goal:** Identify slow queries, missing indexes, table bloat, and connection stats.  
**Time:** ~15 minutes to set up locally.

### 4.1 Prerequisites

Ensure `pg_stat_statements` is enabled in your local PostgreSQL:

```bash
# Connect to your Mastodon database
psql -U your_postgres_user -d your_mastodon_instance_db
```

```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verify
SELECT * FROM pg_stat_statements LIMIT 1;
```

If the extension fails to create, add to `postgresql.conf` and restart Postgres:

```conf
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
```

### 4.2 Add Gem

```ruby
# Gemfile
gem 'pghero'
```

```bash
bundle install
```

### 4.3 Mount Routes

In `config/routes.rb`, protect with your existing master-admin authentication:

```ruby
Rails.application.routes.draw do
  # ... existing routes ...

  authenticate :user, lambda { |u| u.master_admin? } do
    mount PgHero::Engine, at: 'pghero', as: :pghero
  end
end
```

> **Adjust the lambda** to match your master-admin check. If you use a different method (e.g., `u.admin?`, `u.role == 'master'`), update accordingly.

### 4.4 Start and Explore

```bash
bundle exec rails server
```

1. Log in to your dashboard as a master admin.
2. Visit: <http://localhost:3001/pghero>

### 4.5 What to Look For

| Tab                 | What It Shows                                                         | Action for Your Customizations                                                    |
| ------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| **Slow Queries**    | Queries ranked by total execution time (not just individual slowness) | Look for queries hitting `channels`, `channel_posts`, or other custom tables      |
| **Missing Indexes** | Tables/columns scanned frequently without index support               | Check if your custom tables have proper indexes on foreign keys and query filters |
| **Space**           | Table and index sizes, bloat percentage                               | Monitor custom tables for unexpected growth                                       |
| **Connections**     | Live connection count                                                 | Ensure `DB_POOL` in `.env` is appropriate                                         |
| **Live Queries**    | Currently running queries                                             | Spot long-running queries in real time                                            |

### 4.6 PgHero Query Stats Reset (Optional)

During local testing, you may want to reset stats to see only recent activity:

```sql
SELECT pg_stat_statements_reset();
```

---

## 5. Phase 2: OpenTelemetry + Jaeger (Distributed Tracing)

**Goal:** Trace every API request through to its database queries. See exactly which endpoint hits which tables.  
**Time:** ~30 minutes to set up locally.

### 5.1 Add Gems

```ruby
# Gemfile
gem 'opentelemetry-sdk'
gem 'opentelemetry-exporter-otlp'
gem 'opentelemetry-instrumentation-all'
```

```bash
bundle install
```

### 5.2 Create Initializer

Create `config/initializers/opentelemetry.rb`:

```ruby
require 'opentelemetry'
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'patchwork-dashboard-local'
  c.service_version = '1.0.0'

  # Auto-instrument Rails, ActiveRecord, Sidekiq, Redis, HTTP clients, etc.
  c.use_all

  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4318/v1/traces'),
        timeout: 10
      )
    )
  )
end
```

### 5.3 Start Jaeger (Docker)

```bash
docker run -d --name patchwork-jaeger-local   -p 16686:16686   -p 4318:4318   -e COLLECTOR_OTLP_ENABLED=true   jaegertracing/all-in-one:latest
```

- **Jaeger UI:** <http://localhost:16686>
- **OTLP HTTP Endpoint:** <http://localhost:4318/v1/traces>

### 5.4 Start Rails with OTel

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces   bundle exec rails server
```

Or add to your `.env`:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
```

### 5.5 Test and Explore

1. Hit any API endpoint in your browser or Postman:
   - `GET http://localhost:3001/api/channels`
   - `GET http://localhost:3001/admin/channels`
   - Any action that touches your custom tables

2. Open Jaeger UI: <http://localhost:16686>
3. Select **Service** = `patchwork-dashboard-local`
4. Click **Find Traces**
5. Click any trace to see the waterfall:

```
Trace: GET /api/channels
├── http_server_request  GET /api/channels  (total: 145ms)
│   ├── rails_controller   ChannelsController#index  (2ms)
│   ├── active_record      SELECT * FROM channels ...  (12ms)
│   ├── active_record      SELECT * FROM channel_posts ...  (28ms)  ← SLOW
│   ├── active_record      SELECT * FROM accounts ...  (8ms)
│   └── active_record      SELECT COUNT(*) FROM ...  (45ms)  ← SLOW
```

### 5.6 What This Tells Your PM

- **"Which APIs hit the database?"** → Every trace shows the HTTP request and all DB queries it triggered.
- **"Which queries consume the most resources?"** → Sort traces by duration; the longest traces reveal the most expensive API + DB combinations.
- **"Are my custom tables the bottleneck?"** → Look for `active_record` spans referencing `channels`, `channel_posts`, etc.

---

## 6. Phase 3: Prometheus + Grafana (Metrics & Dashboards)

**Goal:** Collect time-series metrics and build dashboards for trends and alerting.  
**Time:** ~30 minutes to set up locally.

### 6.1 Add Prometheus Exporter Gem

```ruby
# Gemfile
gem 'prometheus_exporter'
```

```bash
bundle install
```

### 6.2 Start the Exporter

In a **separate terminal**:

```bash
bundle exec prometheus_exporter
```

- Runs on port `9394`
- Exposes metrics at `http://localhost:9394/metrics`

### 6.3 Start Prometheus (Docker)

Create `prometheus.yml` in your project root:

```yaml
global:
  scrape_interval: 5s
  evaluation_interval: 5s

scrape_configs:
  - job_name: "patchwork-dashboard"
    static_configs:
      - targets: ["host.docker.internal:9394"]
```

```bash
docker run -d --name patchwork-prometheus-local   -p 9090:9090   -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml   prom/prometheus:latest
```

- **Prometheus UI:** <http://localhost:9090>

### 6.4 Start Grafana (Docker)

```bash
docker run -d --name patchwork-grafana-local   -p 3000:3000   -e GF_SECURITY_ADMIN_PASSWORD=admin   grafana/grafana:latest
```

- **Grafana UI:** <http://localhost:3000>
- **Login:** `admin` / `admin`

### 6.5 Configure Grafana

1. **Add Prometheus Datasource:**
   - URL: `http://host.docker.internal:9090` (Mac/Windows) or `http://172.17.0.1:9090` (Linux)
   - Save & Test

2. **Create Your First Dashboard:**

| Panel Name                   | Prometheus Query                                                       | Interpretation                          |
| ---------------------------- | ---------------------------------------------------------------------- | --------------------------------------- |
| **Requests/sec**             | `rate(ruby_http_requests_total[1m])`                                   | API throughput per endpoint             |
| **Avg DB Query Time**        | `ruby_sql_duration_seconds_sum / ruby_sql_duration_seconds_count`      | Average SQL latency across all queries  |
| **DB Query Time (p95)**      | `histogram_quantile(0.95, rate(ruby_sql_duration_seconds_bucket[5m]))` | 95th percentile query latency           |
| **Sidekiq Jobs/sec**         | `rate(ruby_sidekiq_jobs_total[1m])`                                    | Background job throughput               |
| **Puma Thread Usage**        | `ruby_puma_thread_pool_busy / ruby_puma_thread_pool_max`               | Thread pool saturation (alert if > 0.8) |
| **ActiveRecord Connections** | `ruby_active_record_connection_pool_busy`                              | DB connection pool pressure             |

### 6.6 Example Dashboard JSON (Starter)

Save as `grafana-dashboard.json` and import into Grafana:

```json
{
  "dashboard": {
    "title": "Patchwork Dashboard - Local Dev",
    "panels": [
      {
        "title": "Requests per Second",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(ruby_http_requests_total[1m])",
            "legendFormat": "{{controller}}#{{action}}"
          }
        ]
      },
      {
        "title": "DB Query Duration (p95)",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(ruby_sql_duration_seconds_bucket[5m]))",
            "legendFormat": "p95"
          }
        ]
      }
    ]
  }
}
```

---

## 7. Local Development Docker Compose (Optional)

If you prefer a single command to spin up all monitoring sidecars:

```yaml
# docker-compose.monitoring.yml
version: "3.8"

services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: patchwork-jaeger-local
    ports:
      - "16686:16686"
      - "4318:4318"
    environment:
      COLLECTOR_OTLP_ENABLED: "true"
    networks:
      - monitoring

  prometheus:
    image: prom/prometheus:latest
    container_name: patchwork-prometheus-local
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: patchwork-grafana-local
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
```

```bash
docker-compose -f docker-compose.monitoring.yml up -d
```

---

## 8. Production Migration Notes

### PgHero

| Local Dev                                     | Production Recommendation                                |
| --------------------------------------------- | -------------------------------------------------------- |
| Mounted in Rails app (`mount PgHero::Engine`) | Run as separate Docker container (`ankane/pghero`)       |
| Reuses Devise auth                            | Use IP whitelist or reverse-proxy auth                   |
| Connects to local Postgres                    | Connects to production Postgres read replica (preferred) |

**Production Docker Compose snippet:**

```yaml
pghero:
  image: ankane/pghero
  environment:
    DATABASE_URL: postgresql://readonly_user:pass@prod-db-host:5432/mastodon_db
  ports:
    - "8080:8080"
```

### OpenTelemetry

| Local Dev                                 | Production Recommendation                                    |
| ----------------------------------------- | ------------------------------------------------------------ |
| Sends directly to Jaeger                  | Sends to OpenTelemetry Collector                             |
| No sampling                               | Configure head-based sampling (e.g., 10%) to reduce overhead |
| Service name: `patchwork-dashboard-local` | Service name: `patchwork-dashboard-prod`                     |

**Production OTel Collector config (simplified):**

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger]
```

### Prometheus + Grafana

| Local Dev                     | Production Recommendation                                      |
| ----------------------------- | -------------------------------------------------------------- |
| Single Prometheus instance    | Prometheus with persistent volume + federation if multi-region |
| Grafana with default password | Grafana with OAuth/LDAP auth, persistent dashboards            |
| Scrapes local exporter        | Scrapes all app instances via service discovery                |

---

## 9. Mastodon Compatibility Checklist

| Component                    | Compatible? | Notes                                                                                  |
| ---------------------------- | ----------- | -------------------------------------------------------------------------------------- |
| Mastodon Rails app           | ✅ Yes      | Same gems work. Add to Mastodon's `Gemfile` if you want to monitor it too.             |
| Custom tables in shared DB   | ✅ Yes      | PgHero sees all tables. OTel traces all ActiveRecord queries.                          |
| `channels` logic             | ✅ Yes      | Custom models appear in traces as normal ActiveRecord spans.                           |
| Dynamic post character count | ✅ Yes      | If implemented as model/controller logic, it's traced automatically.                   |
| Sidekiq (shared Redis)       | ✅ Yes      | `opentelemetry-instrumentation-all` auto-instruments Sidekiq jobs.                     |
| Doorkeeper / OAuth           | ✅ Yes      | HTTP instrumentation captures OAuth token requests.                                    |
| `strong_migrations`          | ✅ Yes      | Unrelated to monitoring; no conflict.                                                  |
| Existing dev middleware      | ✅ Coexists | `QueryProfiler` and `BulletLogger` stay in dev only. OTel/PgHero are separate systems. |

### Monitoring the Mastodon App Itself

If you also want traces/metrics from the Mastodon app (not just your dashboard):

1. Add the same gems to Mastodon's `Gemfile`.
2. Use a different `service_name` in Mastodon's OTel config (e.g., `mastodon-web`).
3. Both services will appear in Jaeger, and you can trace requests across both if they communicate via HTTP APIs.

---

## 10. Troubleshooting

### PgHero shows "pg_stat_statements not enabled"

```sql
-- Run as superuser in your database
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- If still failing, check postgresql.conf
SHOW shared_preload_libraries;
-- Should include pg_stat_statements
```

### Jaeger shows no traces

1. Verify Jaeger is running: `docker ps | grep jaeger`
2. Check Rails logs for OTel export errors.
3. Ensure `OTEL_EXPORTER_OTLP_ENDPOINT` is set correctly.
4. Verify firewall/Docker networking: from the Rails container, can you reach `jaeger:4318`?

### Prometheus shows "connection refused" to port 9394

1. Ensure `bundle exec prometheus_exporter` is running.
2. Check that port 9394 is not blocked by firewall.
3. In Docker, use `host.docker.internal:9394` (Mac/Windows) or the host's Docker bridge IP (Linux).

### Grafana can't reach Prometheus

1. In Grafana datasource config, use the container name: `http://prometheus:9090` (if on same Docker network).
2. Or use `http://host.docker.internal:9090` if Prometheus is on host.

### High memory usage from OpenTelemetry

In production, enable sampling to reduce overhead:

```ruby
# config/initializers/opentelemetry.rb
OpenTelemetry::SDK.configure do |c|
  # ... other config ...
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      exporter,
      max_queue_size: 2048,
      max_export_batch_size: 512
    )
  )
end
```

---

## Quick Reference: All Ports

| Service             | Local URL                     | Purpose                 |
| ------------------- | ----------------------------- | ----------------------- |
| Patchwork Dashboard | <http://localhost:3001>         | Your Rails app          |
| PgHero              | <http://localhost:3001/pghero>  | PostgreSQL insights     |
| Jaeger UI           | <http://localhost:16686>        | Trace visualization     |
| Prometheus          | <http://localhost:9090>         | Metrics query & storage |
| Grafana             | <http://localhost:3000>         | Metrics dashboards      |
| Prometheus Exporter | <http://localhost:9394/metrics> | Rails metrics endpoint  |

---

## Recommended Order of Implementation

1. **This week:** Phase 1 (PgHero). Explore slow queries and missing indexes. This alone will likely reveal 2-3 quick wins.
2. **Next week:** Phase 2 (OpenTelemetry + Jaeger). Hit your dashboard APIs and watch traces. Focus on understanding the relationship between HTTP requests and DB queries.
3. **Week after:** Phase 3 (Prometheus + Grafana). Build one dashboard panel at a time. Start with request rate and DB latency.
4. **Month 2:** Migrate to production using the production notes above. Start with PgHero on a read replica, then add OTel with sampling.

---

_Generated for the `database-temp1` branch of patchwork_dashboard._
_Compatible with Mastodon v4.x + custom Patchwork Hub tables._
