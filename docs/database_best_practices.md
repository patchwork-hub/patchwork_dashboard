# Database Best Practices — Patchwork Dashboard

These best practices apply to the Patchwork Dashboard Rails 7.1 + PostgreSQL codebase. Each rule is tied to a real pattern in this repository.

---

## 1. Always paginate collections

Returning an unbounded result set loads the database and allocates memory proportional to table size.

### Good example in this repo

[app/controllers/collections_controller.rb](../app/controllers/collections_controller.rb#L9)

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

[app/controllers/keyword_filter_groups_controller.rb](../app/controllers/keyword_filter_groups_controller.rb#L6)

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

[app/controllers/master_admins_controller.rb](../app/controllers/master_admins_controller.rb#L7-L9)

```ruby
allowed_role_ids = UserRole.all.select { |r| r.can?(:administrator) || r.can?(:view_newsmast_dashboard) }.map(&:id)
@master_admins = User.joins(:account)
                      .where(role_id: allowed_role_ids)
                      ...
```

`UserRole.all` fetches every role and evaluates permissions in Ruby. Prefer a database-level check (e.g., `UserRole.where("permissions ? 'administrator' OR permissions ? 'view_newsmast_dashboard'")` if permissions are stored as JSONB/flag columns) or a cached allow-list that does not require a full table scan.

#### Another anti-pattern: filtering in Ruby

[app/controllers/communities_controller.rb](../app/controllers/communities_controller.rb#L386-L390)

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

[app/controllers/custom_emojis_controller.rb](../app/controllers/custom_emojis_controller.rb#L6)

```ruby
def index
  @records = filtered_custom_emojis.eager_load(:local_counterpart, :category).page(params[:page])
  ...
end
```

### Model-level scope example

[app/models/community.rb](../app/models/community.rb#L246-L257)

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

[app/controllers/api/v1/communities_controller.rb](../app/controllers/api/v1/communities_controller.rb#L283-L286)

```ruby
accounts = Account.where(id: account_ids)
accounts.map{ |account| account.following_ids }.flatten.uniq
```

`following_ids` is called on every account. Eager load the `following` association or use a join to fetch the IDs in one query.

#### Another anti-pattern: association inside a loop

[app/controllers/api/v1/community_admins_controller.rb](../app/controllers/api/v1/community_admins_controller.rb#L63)

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

[app/controllers/keyword_filter_groups_controller.rb](../app/controllers/keyword_filter_groups_controller.rb#L110-L112)

```ruby
keyword_filters.find_each do |kf|
  ...
end
```

Use `find_each` or `find_in_batches` whenever the dataset is unbounded or large.

---

## 5. Use read replicas for read-heavy endpoints

The `feat-db-WR` branch already configures primary + replica in [config/database.yml](../config/database.yml#L19-L30). Use the helpers in [app/helpers/database_helper.rb](../app/helpers/database_helper.rb):

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

[app/controllers/base_controller.rb](../app/controllers/base_controller.rb#L8)

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

[app/models/community.rb](../app/models/community.rb#L232-L244)

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
- **Custom query profiler** — [lib/middleware/query_profiler.rb](../lib/middleware/query_profiler.rb) adds an `X-SQL-Profile` header. It is currently commented out in [config/application.rb](../config/application.rb#L41-L42); enable it temporarily for API debugging.

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
