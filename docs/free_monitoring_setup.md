# Free Monitoring Stack Setup — Patchwork Dashboard

This guide explains how to set up a free, self-hosted monitoring stack for the Patchwork Dashboard Rails application. The tools are open source; the only costs are the AWS compute and storage resources they run on.

**Target environment:** AWS ECS / EKS / Fargate (also includes a local Docker Compose path).

---

## Tools

| Tool | Purpose | License |
| ---- | ------- | ------- |
| lograge | Structured Rails request logs | MIT |
| prometheus_exporter | Rails metrics endpoint | MIT |
| Prometheus | Time-series metrics collection | Apache 2.0 |
| Grafana | Dashboards and alerting | AGPL-3.0 |
| PgHero | PostgreSQL query and index insights | MIT |
| postgres_exporter | PostgreSQL metrics for Prometheus | Apache 2.0 |

---

## Part 1 — Application-side changes

### 1.1 Add `lograge` for structured request logging

Add to the `Gemfile`:

```ruby
gem 'lograge'
gem 'logstash-event' # optional, for Logstash-compatible JSON
```

Create or update [config/initializers/lograge.rb](../config/initializers/lograge.rb):

```ruby
Rails.application.configure do
  config.lograge.enabled = Rails.env.production? || ENV['LOGRAGE_ENABLED'].present?
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.include_controller_and_action = true
  config.lograge.custom_payload do |controller|
    {
      host: controller.request.host,
      user_id: controller.current_user&.id
    }
  end
end
```

In Docker Compose / ECS, set `RAILS_LOG_TO_STDOUT=true` (already set in the [Dockerfile](../Dockerfile)) so logs flow to CloudWatch or your log aggregator.

### 1.2 Add `prometheus_exporter` for Rails metrics

Add to the `Gemfile`:

```ruby
gem 'prometheus_exporter'
```

Add a metrics initializer [config/initializers/prometheus.rb](../config/initializers/prometheus.rb):

```ruby
unless Rails.env.test?
  require 'prometheus_exporter/instrumentation'
  require 'prometheus_exporter/middleware'

  PrometheusExporter::Instrumentation::Process.start(type: 'master')
  Rails.middleware.unshift PrometheusExporter::Middleware
  PrometheusExporter::Instrumentation::ActiveRecord.start(
    custom_labels: { type: 'patchwork_dashboard' },
    config_labels: [:database, :host]
  )
  PrometheusExporter::Instrumentation::Sidekiq.start
end
```

Start the exporter in a separate process. For local development:

```bash
bundle exec prometheus_exporter --bind 0.0.0.0 --port 9394
```

For Docker / ECS, run it as a sidecar or separate container using the same image:

```dockerfile
CMD ["bundle", "exec", "prometheus_exporter", "--bind", "0.0.0.0", "--port", "9394"]
```

The exporter exposes metrics at `/metrics` on port `9394`.

---

## Part 2 — Local development monitoring

A `docker-compose.monitoring.yml` is provided in [docs/monitoring/examples/docker-compose.monitoring.yml](monitoring/examples/docker-compose.monitoring.yml).

### 2.1 Start the stack locally

```bash
docker compose -f docker-compose.yml -f docs/monitoring/examples/docker-compose.monitoring.yml up -d
```

### 2.2 Access the tools

| Tool | URL |
| ---- | --- |
| Grafana | `http://localhost:3000` (admin / admin) |
| Prometheus | `http://localhost:9090` |
| PgHero | `http://localhost:8080` |

### 2.3 PgHero setup

PgHero needs a dedicated read-only PostgreSQL user:

```sql
CREATE USER pghero WITH PASSWORD 'secure_password';
GRANT pg_monitor TO pghero;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO pghero;
```

---

## Part 3 — AWS deployment architecture

### 3.1 Recommended layout

```text
┌──────────────────────┐     ┌──────────────────────┐
│   Application ECS    │     │   Monitoring Stack   │
│  Service (Fargate)   │     │  (separate cluster)  │
│                      │     │                      │
│  Rails containers    │     │  Prometheus task     │
│  Sidekiq workers     │     │  Grafana task        │
│  prometheus_exporter │────▶│  PgHero task         │
│        sidecar       │     │  postgres_exporter   │
└──────────────────────┘     └──────────────────────┘
           │                            │
           └──────────┬─────────────────┘
                      │
              ┌───────▼────────┐
              │   PostgreSQL   │
              │  (RDS / self)  │
              └────────────────┘
```

Keeping monitoring in a separate ECS cluster or Kubernetes namespace limits blast radius and makes security rules simpler.

### 3.2 Networking

- Place the Rails `prometheus_exporter` sidecar on an internal port (`9394`) that is **not** exposed to the public internet.
- Use a security group rule that allows Prometheus to scrape `9394` only from the monitoring cluster.
- PgHero and `postgres_exporter` connect to RDS with a read-only user and should be in the same VPC / private subnets.
- Grafana should be behind an internal ALB or VPN. If public access is required, restrict it by IP and enforce HTTPS + authentication.

### 3.3 Persistent storage

Prometheus and Grafana need persistent volumes:

| Tool | Storage need | AWS option |
| ---- | ------------ | ---------- |
| Prometheus TSDB | 50–200 GB, grows with retention | EFS or EBS CSI on EKS |
| Grafana dashboards/users | Small | EFS or RDS for user DB |

**Prerequisite:** provision EFS (for ECS) or an EBS-backed PVC (for EKS) before deploying.

### 3.4 Example manifests

See:

- [docs/monitoring/examples/prometheus-task.json](monitoring/examples/prometheus-task.json)
- [docs/monitoring/examples/grafana-task.json](monitoring/examples/grafana-task.json)
- [docs/monitoring/examples/pghero-task.json](monitoring/examples/pghero-task.json)
- [docs/monitoring/examples/prometheus.yml](monitoring/examples/prometheus.yml)

These are ECS Fargate task definitions. For EKS, convert them to Deployments + Services with the same container images and environment variables.

### 3.5 Prometheus scrape targets

Add these to [docs/monitoring/examples/prometheus.yml](monitoring/examples/prometheus.yml):

```yaml
scrape_configs:
  - job_name: 'rails-app'
    static_configs:
      - targets: ['patchwork-dashboard.your-vpc.local:9394']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter.your-vpc.local:9187']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter.your-vpc.local:9100']
```

For dynamic ECS tasks, use the [Prometheus ECS service discovery](https://github.com/prometheus-community/ecs_exporter) or an operator on EKS.

---

## Part 4 — Retention and security

### 4.1 Retention

Set Prometheus retention to balance cost and history. For a Rails app of this size, start with 30 days:

```yaml
# prometheus.yml or task command
args:
  - '--storage.tsdb.retention.time=30d'
  - '--storage.tsdb.retention.size=50GB'
```

Back up the EFS volume regularly using AWS Backup.

### 4.2 Security hardening

- Run Grafana with HTTPS only and change the default admin password immediately.
- Store database passwords in AWS Secrets Manager; pass them via environment variables.
- Restrict Prometheus scrape targets to internal security groups.
- Give PgHero and `postgres_exporter` a read-only database user.
- Disable `X-SQL-Profile` middleware in production.
- Do not expose the `prometheus_exporter` `/metrics` endpoint to the public.

### 4.3 Cost estimate (AWS)

There are no license fees for the tools. Expect charges for:

- Fargate vCPU/GB for Prometheus, Grafana, and PgHero tasks.
- EFS storage and throughput for Prometheus/Grafana data.
- Data transfer between VPCs if monitoring runs in a separate VPC.
- CloudWatch Logs if logs are sent there.

A small setup (2 vCPU / 4 GB total, 100 GB EFS) typically runs under **$100–150/month** in `us-east-1`.

---

## Part 5 — Alerting (optional, but recommended)

Grafana supports alert rules based on Prometheus metrics. Alerting is not configured by default in this guide because the team has not chosen a destination yet.

When you are ready, create a Grafana contact point for:

- Slack webhook
- Email (SMTP)
- Discord webhook
- PagerDuty / Opsgenie

Suggested starter alerts:

| Alert | PromQL example |
| ----- | -------------- |
| High 95th percentile request duration | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1` |
| High error rate | `rate(http_requests_total{status=~"5.."}[5m]) > 0.05` |
| Sidekiq queue backlog | `ruby_sidekiq_queue_backlog > 1000` |
| PostgreSQL connections near limit | `pg_stat_activity_count / pg_settings_max_connections > 0.8` |
| Replica lag (when replica enabled) | `pg_replication_lag_seconds > 5` |

---

## Part 6 — Verification checklist

After deploying monitoring:

- [ ] Rails logs are structured JSON and flowing to CloudWatch / aggregator.
- [ ] `prometheus_exporter` is reachable from Prometheus and `/metrics` returns data.
- [ ] Prometheus scrapes Rails, PostgreSQL, and node metrics successfully.
- [ ] Grafana dashboards show Rails request latency, throughput, and SQL metrics.
- [ ] PgHero shows slow queries and index suggestions.
- [ ] Persistent volumes are mounted and survive task restarts.
- [ ] No monitoring endpoint is publicly accessible without authentication.
- [ ] Alerting contact points are configured (when ready).

---

## Next steps

1. Decide whether to deploy on ECS, EKS, or Docker Compose.
2. Provision persistent storage.
3. Create a read-only PostgreSQL user for PgHero and `postgres_exporter`.
4. Add `lograge` and `prometheus_exporter` to the application.
5. Deploy the monitoring stack using the example manifests.
6. Import the Grafana dashboards and configure retention.
7. Set up alerting once the team chooses Slack/email/Discord.
