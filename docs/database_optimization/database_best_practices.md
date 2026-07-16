# Database Best Practices — Patchwork Dashboard

These best practices apply to the Patchwork Dashboard Rails 7.1 + PostgreSQL codebase. Each rule is tied to a real pattern in this repository.

---

## 1. Always paginate collections

Returning an unbounded result set loads the database and allocates memory proportional to table size.

### Good example in this repo

[app/controllers/collections_controller.rb](../../app/controllers/collections_controller.rb#L9)

```ruby
PER_PAGE = 10

def index
  with_read_replica do
    @search = Collection.ransack(params[:q])
    @records = @search.result.order(:sorting_index).page(params[:page]).per(PER_PAGE).load
  end
end
```

The controller also wraps the read in `with_read_replica`, so it routes to the replica when one is configured.

### Anti-pattern to avoid

[app/controllers/keyword_filter_groups_controller.rb](../../app/controllers/keyword_filter_groups_controller.rb#L6)

```ruby
def index
  @keyword_filter_groups = KeywordFilterGroup.all
end
```

This returns every row. Prefer `.page(params[:page]).per(PER_PAGE)` or a similar cursor/pagination strategy.

---

## 2. Filter at the database, not in Ruby

Loading records into memory and then calling `select`, `reject`, or `map` is almost always slower than using `where`, `joins`, or `pluck`.

### Anti-pattern in this repo

[app/controllers/master_admins_controller.rb](../../app/controllers/master_admins_controller.rb#L7-L9)

```ruby
allowed_role_ids = UserRole.all.select { |r| r.can?(:administrator) || r.can?(:view_newsmast_dashboard) }.map(&:id)
@master_admins = User.joins(:account)
                      .where(role_id: allowed_role_ids)
                      ...
```

`UserRole.all` fetches every role and evaluates permissions in Ruby. Prefer a database-level check (e.g., `UserRole.where("permissions ? 'administrator' OR permissions ? 'view_newsmast_dashboard'")` if permissions are stored as JSONB/flag columns) or a cached allow-list that does not require a full table scan.

#### Another anti-pattern: filtering in Ruby

[app/controllers/communities_controller.rb](../../app/controllers/communities_controller.rb#L386-L390)

```ruby
accounts = Account.where(id: account_ids)
@follow_records_size = accounts.reject { |r| r.username == 'bsky.brid.gy' }.size
```

The `.reject` loads every account into memory. Prefer:

```ruby
@follow_records_size = Account.where(id: account_ids)
                               .where.not(username: 'bsky.brid.gy')
                               .count
```

---

## 3. Eager-load associations used in loops and serializers

Iterating over a collection and touching associations produces N+1 queries. Use `includes`, `preload`, or `eager_load` depending on the access pattern.

### Good example

[app/controllers/custom_emojis_controller.rb](../../app/controllers/custom_emojis_controller.rb#L6)

```ruby
def index
  @records = filtered_custom_emojis.eager_load(:local_counterpart, :category).page(params[:page])
  ...
end
```

### Model-level scope example

[app/models/community.rb](../../app/models/community.rb#L246-L257)

```ruby
scope :with_all_includes, -> {
  includes(
    :content_type,
    :patchwork_community_type,
    :patchwork_community_hashtags,
    :patchwork_community_rules,
    :patchwork_community_additional_informations,
    :patchwork_community_links
  )
}
```

### Anti-pattern: following_ids inside a loop

[app/controllers/api/v1/communities_controller.rb](../../app/controllers/api/v1/communities_controller.rb#L283-L286)

```ruby
accounts = Account.where(id: account_ids)
accounts.map{ |account| account.following_ids }.flatten.uniq
```

`following_ids` is called on every account. Eager load the `following` association or use a join to fetch the IDs in one query.

#### Another anti-pattern: association inside a loop

[app/controllers/api/v1/community_admins_controller.rb](../../app/controllers/api/v1/community_admins_controller.rb#L63)

```ruby
communities.each do |community|
  community_admin = community.community_admins.first
  ...
end
```

`community.community_admins.first` issues a query per community. Prefer `.includes(:community_admins)` on the initial `Community` query.

---

## 4. Prefer `find_each` for large batches

When exporting CSV or processing many rows, `find_each` fetches records in batches rather than loading the entire relation.

### Good example: batched CSV export

[app/controllers/keyword_filter_groups_controller.rb](../../app/controllers/keyword_filter_groups_controller.rb#L110-L112)

```ruby
keyword_filters.find_each do |kf|
  ...
end
```

Use `find_each` or `find_in_batches` whenever the dataset is unbounded or large.

---

## 5. Use read replicas for read-heavy endpoints

The `feat-db-WR` branch already configures primary + replica in [config/database.yml](../config/database.yml#L19-L30). Use the helpers in [app/helpers/database_helper.rb](../../app/helpers/database_helper.rb):

```ruby
module DatabaseHelper
  def with_read_replica(&block)
    if replica_enabled?
      ApplicationRecord.connected_to(role: :reading, prevent_writes: true, &block)
    else
      yield
    end
  end

  def with_primary(&block)
    if replica_enabled?
      ApplicationRecord.connected_to(role: :writing, &block)
    else
      yield
    end
  end
end
```

Wrap read-only controller actions in `with_read_replica` and any writes in `with_primary`.

### Example

[app/controllers/base_controller.rb](../../app/controllers/base_controller.rb#L8)

```ruby
def index
  with_read_replica do
    ...
  end
end
```

### Replica safety rules

- Do **not** perform writes inside `with_read_replica` (`prevent_writes: true` helps, but be careful with callbacks).
- Do **not** mix replica reads and primary writes in the same transaction. Wrap the whole transaction on the primary.
- Be aware of replica lag when a job reads data it just wrote. In Sidekiq jobs, default to the primary unless the job is purely read-only.
- See the existing replica guideline: [read_write_database_guideline.md](read_write_database_guideline.md)

---

## 6. Keep scopes chainable and explicit

Scopes that are easy to chain encourage reuse and help avoid duplicating conditions.

### Good example: reusable scopes

[app/models/community.rb](../../app/models/community.rb#L232-L244)

```ruby
scope :filter_channels, -> { where(patchwork_communities: { channel_type: Community.channel_types[:channel] }).exclude_deleted_channels }
scope :filter_channel_feeds, -> { where(patchwork_communities: { channel_type: Community.channel_types[:channel_feed] }).exclude_deleted_channels }
scope :exclude_deleted_channels, -> { where(patchwork_communities: { deleted_at: nil }) }
```

---

## 7. Index intentionally

Patchwork uses PostgreSQL. Common indexing opportunities in this app:

- Foreign keys (e.g., `patchwork_communities_admins.account_id`, `patchwork_communities_statuses.status_id`).
- Columns used in `where`, `order`, and `join` clauses.
- Partial indexes for soft-deleted records: `WHERE deleted_at IS NULL`.
- GIN indexes for JSONB/search columns such as `accounts.fields` or full-text search.

Always use [strong_migrations](https://github.com/ankane/strong_migrations) conventions to add indexes safely on large tables:

```ruby
class AddIndexToPatchworkCommunitiesStatuses < ActiveRecord::Migration[7.1]
  def change
    add_index :patchwork_communities_statuses, :status_id, algorithm: :concurrently
  end
end
```

Use `algorithm: :concurrently` and avoid adding indexes inside a transaction for large tables.

---

## 8. Avoid SELECT * on wide tables

Tables like `accounts` carry paperclip attachments and JSONB columns. Selecting all columns for list views increases memory and network overhead.

Prefer `.select(...)` for list views:

```ruby
Account.where(...).select(:id, :username, :display_name, :domain)
```

---

## 9. Profile locally before opening a PR

The repo already ships with profiling tools. Use them:

- **Bullet** — detects N+1 queries and unused eager loading. Enabled in development/test.
- **rack-mini-profiler** — shows request timing, SQL, and memory in the browser footer.
- **Custom query profiler** — [lib/middleware/query_profiler.rb](../../lib/middleware/query_profiler.rb) adds an `X-SQL-Profile` header. It is currently commented out in [config/application.rb](../../config/application.rb#L41-L42); enable it temporarily for API debugging.

See [database_development_guideline.md](database_development_guideline.md) for the exact workflow.

---

## 10. Test with realistic data

N+1 queries and slow filters only appear once tables grow. Before merging performance-sensitive changes:

- Test with a production-like dataset when possible.
- Use `EXPLAIN ANALYZE` on the generated SQL.
- Verify behavior with both primary-only and primary+replica configurations.

---

## Summary checklist

- [ ] Pagination is used on every list/API endpoint.
- [ ] Filtering happens in SQL, not Ruby.
- [ ] Associations used in loops are eager-loaded.
- [ ] Bulk exports use `find_each` / `find_in_batches`.
- [ ] Read-only actions prefer `with_read_replica`.
- [ ] Writes are wrapped in `with_primary` and not mixed with replica reads.
- [ ] New indexes use `algorithm: :concurrently` via `strong_migrations`.
- [ ] List views select only the columns they need.
- [ ] Bullet/rack-mini-profiler are checked during local development.

---

## 11. Additional Ruby on Rails best practices

The rules above are tied to patterns already found in Patchwork Dashboard. The following guidelines are also worth adopting as the codebase grows.

### 11.1 Prefer `exists?` / `any?` / `none?` over `present?` / `empty?`

`present?` and `empty?` on an Active Record relation load records into memory. Use relation-level predicates when you only need to know whether rows exist.

```ruby
# Good
User.where(active: true).exists?
Account.where(domain: 'example.com').any?
Community.where(deleted_at: nil).none?

# Avoid
User.where(active: true).present?
Account.where(domain: 'example.com').empty?
```

### 11.2 Use `pluck` / `pick` for value-only access

Avoid instantiating Active Record objects when you only need column values.

```ruby
# Good
Account.where(domain: 'example.com').pluck(:id, :username)
Account.where(username: 'admin').pick(:id, :display_name)

# Avoid
Account.where(domain: 'example.com').map { |a| [a.id, a.username] }
```

### 11.3 Batch inserts and upserts

For imports, seeds, or syncs, use `insert_all` / `upsert_all` to generate a single SQL statement instead of creating records one by one.

```ruby
# Good
User.insert_all([
  { email: 'a@example.com', created_at: Time.current, updated_at: Time.current },
  { email: 'b@example.com', created_at: Time.current, updated_at: Time.current }
])

User.upsert_all(
  [{ id: 1, email: 'a@example.com' }],
  unique_by: :email
)
```

> `insert_all` / `upsert_all` skip validations and callbacks. Use them only when that is safe, or validate the data beforehand.

### 11.4 Counter caches

Use Rails counter caches to avoid repeated `COUNT(*)` queries on associations.

```ruby
# Migration
add_column :posts, :comments_count, :integer, default: 0, null: false

# Model
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end

# Use post.comments_count instead of post.comments.count
```

Backfill existing data with a one-off background job or rake task.

### 11.5 Use transactions deliberately

Wrap multi-step writes in a database transaction so partial failures roll back cleanly.

```ruby
# Good
ActiveRecord::Base.transaction do
  order = Order.create!(...)
  order.items.create!(...)
  payment.charge!
end
```

Avoid long-running transactions and do not call external APIs inside a transaction.

### 11.6 Avoid heavy work in callbacks

Callbacks that send email, call external services, or enqueue many jobs make models hard to reason about and can slow writes. Prefer explicit service objects.

```ruby
# Avoid
class User < ApplicationRecord
  after_create :send_welcome_email, :notify_slack, :sync_crm
end

# Better
class UserRegistrationService
  def call(user)
    user.save!
    UserMailer.welcome(user).deliver_later
    SlackNotifier.new_user(user)
    CrmSyncJob.perform_later(user.id)
  end
end
```

### 11.7 Enqueue jobs after commit when they read their own writes

If a job enqueued inside a transaction reads the record it just created, use `after_commit` or pass the ID and reload. Otherwise the job may run before the commit is visible.

```ruby
# Avoid
after_create :enqueue_index_job

# Better
after_commit :enqueue_index_job, on: [:create, :update]
```

### 11.8 Background job hygiene

- Keep jobs idempotent and retry-safe.
- Pass IDs, not Active Record objects.
- Use dedicated queues for slow/reporting work.
- Set sensible retry limits and dead-letter handling.

```ruby
class GenerateReportJob < ApplicationJob
  queue_as :reports

  def perform(community_id)
    community = Community.find(community_id)
    # idempotent work
  end
end
```

### 11.9 Cache hot, rarely-changing data

Use Rails cache to reduce database load for frequently accessed data.

```ruby
# Fragment caching
<% cache community do %>
  <%= render community %>
<% end %>

# Low-level caching
def total_active_users
  Rails.cache.fetch("stats/active_users", expires_in: 5.minutes) do
    User.active.count
  end
end
```

For nested partials, use Russian Doll caching with `touch: true` on parent associations.

### 11.10 Size the database connection pool

Ensure `pool` matches Puma + Sidekiq concurrency to avoid `ConnectionTimeoutError`.

```yaml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5).to_i + ENV.fetch("SIDEKIQ_CONCURRENCY", 0).to_i %>
```

### 11.11 Use `EXPLAIN ANALYZE` for complex queries

Before merging a complex query, review the execution plan.

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM accounts
WHERE domain = 'example.com'
ORDER BY created_at DESC
LIMIT 20;
```

Watch for sequential scans on large tables, high buffer counts, and nested loops over large relations.

### 11.12 Avoid SQL injection

Never interpolate user input into SQL strings. Use parameterized queries.

```ruby
# Good
User.where("email = ?", params[:email])
User.where(email: params[:email])

# Never
User.where("email = '#{params[:email]}'")
```

### 11.13 Use strong parameters

Always whitelist params before passing them to `create` or `update`.

```ruby
def user_params
  params.require(:user).permit(:email, :display_name, :role_id)
end
```

### 11.14 Use database views for complex reports

For complex read-only reports, consider PostgreSQL views or materialized views to pre-compute results.

```ruby
# Migration
execute <<-SQL
  CREATE MATERIALIZED VIEW community_stats AS
    SELECT community_id, COUNT(*) AS posts_count
    FROM patchwork_communities_statuses
    GROUP BY community_id;
SQL

add_index :community_stats, :community_id, unique: true
```

Refresh concurrently on a schedule:

```ruby
ActiveRecord::Base.connection.execute(
  "REFRESH MATERIALIZED VIEW CONCURRENTLY community_stats"
)
```

### 11.15 Default scopes and `unscoped`

Default scopes often cause surprising queries and N+1s. Prefer explicit scopes.

```ruby
# Avoid
default_scope { where(deleted_at: nil) }

# Better
scope :active, -> { where(deleted_at: nil) }
```

If you must override a scope, use `unscoped` sparingly and document why.

### 11.16 JSONB queries

For JSONB columns, use PostgreSQL operators (`?`, `->`, `@>`) and GIN indexes.

```ruby
# Good
Account.where("fields @> ?", [{ name: "Website" }].to_json)

# Migration
add_index :accounts, :fields, using: :gin, algorithm: :concurrently
```

Avoid loading large JSONB payloads in list views.

### 11.17 Health checks

Add lightweight health endpoints for load balancers and orchestrators.

```ruby
class HealthController < ApplicationController
  def index
    ActiveRecord::Base.connection.execute('SELECT 1')
    head :ok
  rescue
    head :service_unavailable
  end
end
```

Use separate liveness (`/health`) and readiness (`/ready`) probes that also check Redis/DB when appropriate.
