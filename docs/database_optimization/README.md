# Patchwork Dashboard Database Optimization & Monitoring

This directory contains the database optimization playbook for the Patchwork Dashboard Rails application. It is intended for the whole engineering team and covers best practices, known slow queries, day-to-day guidelines, query-writing rules, and a step-by-step guide for setting up free, self-hosted monitoring tools.

## Documents

1. [database_best_practices.md](database_best_practices.md) — Ruby on Rails + PostgreSQL best practices mapped to real code in this repo.
2. [slow_query_inventory.md](slow_query_inventory.md) — Prioritized list of slow / inefficient queries that need fixing, with suggested fixes.
3. [database_development_guideline.md](database_development_guideline.md) — How to work day-to-day, review code, and verify changes safely.
4. [query_rules_and_principles.md](query_rules_and_principles.md) — Short reference card of hard rules for writing queries.
5. [monitoring_and_observability_setup.md](monitoring_and_observability_setup.md) — Canonical guide for monitoring and observability (Prometheus/Grafana/PgHero/lograge baseline, optional OpenTelemetry tracing, and Patchwork compatibility notes).

## Quick links to existing code

- Read/write replica configuration: [config/database.yml](../../config/database.yml)
- Replica helper methods: [app/helpers/database_helper.rb](../../app/helpers/database_helper.rb)
- Example replica usage in a controller: [app/controllers/base_controller.rb](../../app/controllers/base_controller.rb)
- Existing query profiler middleware: [lib/middleware/query_profiler.rb](../../lib/middleware/query_profiler.rb)
- Where the profiler is currently disabled: [config/application.rb](../../config/application.rb#L41-L42)
- N+1 detection initializer: [config/initializers/bullet.rb](../../config/initializers/bullet.rb)
- Local request profiler initializer: [config/initializers/rack_profiler.rb](../../config/initializers/rack_profiler.rb)
- Existing multi-DB guideline: [read_write_database_guideline.md](read_write_database_guideline.md)
