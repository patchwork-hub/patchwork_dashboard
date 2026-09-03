# Database Development Guideline — Patchwork Dashboard

This guide describes the day-to-day workflow every team member should follow when working with Active Record, PostgreSQL, and the read-write replica setup in this project.

---

## 1. Local development workflow

### 1.1 Use the tools that are already installed

The repo already includes the tools you need for day-to-day query debugging:

- **Bullet** — N+1 query detection. Configured in [config/initializers/bullet.rb](../../config/initializers/bullet.rb).
- **rack-mini-profiler** — Request timing and SQL counts in the browser footer. Configured in [config/initializers/rack_profiler.rb](../../config/initializers/rack_profiler.rb).
- **Custom query profiler** — [lib/middleware/query_profiler.rb](../../lib/middleware/query_profiler.rb) adds an `X-SQL-Profile` header. It is currently commented out in [config/application.rb](../../config/application.rb#L41-L42).

### 1.2 Enable the custom query profiler for API debugging

If you are debugging an API endpoint, temporarily enable the middleware:

```ruby
# config/application.rb
config.middleware.insert_after ActionDispatch::Executor, BulletLogger
config.middleware.insert_before 0, QueryProfiler
```

Then inspect the response headers:

```bash
curl -s -D - http://localhost:3000/api/v1/communities | grep -i x-sql-profile
```

**Do not commit this change enabled in production.** Keep it behind a local-only flag or disable it before pushing.

### 1.3 Watch the Rails log

Keep an eye on:

- Repeated identical queries in the same request (sign of N+1).
- Queries with no `LIMIT` on list endpoints.
- Queries selecting many columns for list views.
- Queries that run for hundreds of milliseconds in development (they will be worse in production).

### 1.4 Run baseline metrics when appropriate

The repo has a baseline monitoring task:

```bash
bundle exec rake db:analyze_baseline
```

Set `BASELINE_API_KEY` and `BASELINE_API_SECRET` to avoid 403-only metrics. Use this before and after large query changes to measure impact.

---

## 2. Before you write a query

Ask these questions:

1. **Will this relation ever be large?** If yes, paginate it.
2. **Am I filtering data in Ruby?** Move the condition to SQL.
3. **Will I touch an association inside a loop?** Eager-load it with `includes` / `preload` / `eager_load`.
4. **Is this a read-only path?** Use `with_read_replica`.
5. **Does this path write data?** Use `with_primary` and avoid mixing replica reads in the same transaction.

---

## 3. Read-write replica guidelines

The project uses Rails 7.1 multi-database support. The replica is configured in [config/database.yml](../config/database.yml) and the helpers live in [app/helpers/database_helper.rb](../../app/helpers/database_helper.rb).

### 3.1 When to use `with_read_replica`

Use it for actions that only read and do not need the very latest write:

```ruby
def index
  with_read_replica do
    @records = Model.page(params[:page]).per(PER_PAGE)
  end
end
```

Good candidates: index/show endpoints, CSV generation, analytics, serializers that do not depend on a just-written row.

### 3.2 When to use `with_primary`

Use it when you write or when you read data that was just written:

```ruby
def create
  with_primary do
    @record = Model.create!(record_params)
    redirect_to @record
  end
end
```

### 3.3 Sidekiq jobs

Sidekiq jobs should default to the primary to avoid reading stale data after a write. If a job is purely read-only (e.g., a report generator), you may route it to the replica, but document why.

### 3.4 Testing with replicas

- Test DB does not use replicas by design.
- If you add replica-aware code, verify it with a local staging-like setup:

```bash
RAILS_ENV=staging rails c
ApplicationRecord.connected_to(role: :replica) { Account.count }
```

- Always confirm writes reach the primary and replicas see them after lag.

For more pitfalls, see [read_write_database_guideline.md](read_write_database_guideline.md).

---

## 4. Code review checklist

For every controller, serializer, service, or job that touches the database:

- [ ] **Pagination**: Every list/API endpoint uses pagination.
- [ ] **No full-table loads**: `.all` without pagination is not used for rendering.
- [ ] **Database-level filtering**: No `select { ... }`, `reject { ... }`, or `map` on large relations to reduce data.
- [ ] **Eager loading**: Associations used in loops or serializers are eager-loaded.
- [ ] **Bulk processing**: Large exports use `find_each` / `find_in_batches`.
- [ ] **Replica safety**: Read-only actions use `with_read_replica`; writes use `with_primary`.
- [ ] **No mixed-role transactions**: Do not read from the replica then write inside the same transaction on the primary.
- [ ] **Indexes**: New `where`/`order` columns have appropriate indexes added via `strong_migrations`.
- [ ] **Column selection**: List views select only needed columns.
- [ ] **SQL reviewed**: Use `EXPLAIN ANALYZE` for new complex queries.

---

## 5. Running tests

### 5.1 Basic test run

```bash
bundle exec rails test
```

### 5.2 Common test issues

- If the test DB has active sessions or pending migrations, clear sessions and run migrations:

```bash
RAILS_ENV=test bundle exec rails db:drop db:create db:migrate
bundle exec rails test
```

- If schema load fails with `PG::UndefinedFunction: timestamp_id(text)`, the test database was created without the required PostgreSQL helper function. Rebuild the schema in a clean DB after the migration that defines the helper:

```bash
RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load
```

- Bullet is loaded in development and test but guarded with `defined?(Bullet)`. If you see Bullet-related boot errors, confirm the gem is in the bundle.

### 5.3 Performance regression tests

If you add a performance test, use `rack-mini-profiler` or benchmark the request externally:

```bash
ab -n 100 -c 5 http://localhost:3000/collections
```

For SQL-level benchmarking, use PostgreSQL directly:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM patchwork_communities WHERE deleted_at IS NULL;
```

---

## 6. Commit and PR guidelines

When submitting database-related changes:

1. Reference the slow-query inventory or rule number that motivated the change.
2. Include `EXPLAIN ANALYZE` output in the PR description for complex queries.
3. Mention whether the change affects read-write replica routing.
4. Add or update tests if the query shape changes.
5. Run the full test suite before requesting review.
