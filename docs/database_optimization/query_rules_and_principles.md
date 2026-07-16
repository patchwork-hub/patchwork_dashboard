# Query Rules & Principles — Patchwork Dashboard

A short, hard-rules reference card for everyone writing Active Record queries in this project.

---

## Rule 1 — Always paginate collections

A list endpoint must never return an unbounded number of rows.

**Allowed:**

```ruby
@records = Collection.page(params[:page]).per(PER_PAGE)
```

**Not allowed:**

```ruby
@records = Collection.all
```

See [collections_controller.rb](../../app/controllers/collections_controller.rb#L9) for the project convention.

---

## Rule 2 — Filter in SQL, not Ruby

Move `where`, `not`, `or`, and `in` conditions into the database query.

**Allowed:**

```ruby
Account.where(id: account_ids).where.not(username: 'bsky.brid.gy').count
```

**Not allowed:**

```ruby
accounts = Account.where(id: account_ids)
accounts.reject { |r| r.username == 'bsky.brid.gy' }.size
```

See [slow_query_inventory.md](slow_query_inventory.md#3-load_follow_records-filters-accounts-in-ruby-after-loading-them).

---

## Rule 3 — Eager-load associations used in loops

If you touch an association for every element of a collection, preload it.

**Allowed:**

```ruby
@records = CustomEmoji.eager_load(:local_counterpart, :category).page(params[:page])
```

**Not allowed:**

```ruby
accounts.map { |account| account.following_ids }.flatten.uniq
```

Use a join or `pluck` instead:

```ruby
Follow.where(account_id: account_ids).pluck(:target_account_id).uniq
```

See [slow_query_inventory.md](slow_query_inventory.md#4-fetch_contributors-triggers-n1-following_ids-queries).

---

## Rule 4 — Avoid N+1 in serializers and JSON builders

Serializers often iterate associations. Make sure they are loaded before serialization.

**Allowed:**

```ruby
community = Community.with_all_includes.find(params[:id])
render json: CommunitySerializer.new(community)
```

**Not allowed:**

```ruby
communities.each do |community|
  community.community_admins.first
end
```

Prefer:

```ruby
Community.includes(:community_admins).find_each do |community|
  ...
end
```

See [slow_query_inventory.md](slow_query_inventory.md#5-boost_bot_accounts_list-queries-community_admins-once-per-community).

---

## Rule 5 — Use `find_each` / `find_in_batches` for large datasets

Exports, backfills, and reports must stream or batch data.

**Allowed:**

```ruby
KeywordFilter.joins(:keyword_filter_group)
             .where(keyword_filter_groups: { server_setting_id: id })
             .find_each do |kf|
  ...
end
```

**Not allowed:**

```ruby
KeywordFilter.joins(:keyword_filter_group).where(...).each do |kf|
  ...
end
```

---

## Rule 6 — Route reads to the replica, writes to the primary

Use the helpers from [app/helpers/database_helper.rb](../../app/helpers/database_helper.rb).

**Read-only:**

```ruby
def index
  with_read_replica do
    @records = Model.page(params[:page])
  end
end
```

**Write:**

```ruby
def create
  with_primary do
    @record = Model.create!(params)
  end
end
```

---

## Rule 7 — Never mix replica reads and primary writes in one transaction

Do not do this:

```ruby
with_read_replica do
  user = User.find(params[:id])
end
with_primary do
  ActiveRecord::Base.transaction do
    user.update!(...)  # user was loaded on replica; may be stale
  end
end
```

Do this instead:

```ruby
with_primary do
  ActiveRecord::Base.transaction do
    user = User.find(params[:id])
    user.update!(...)
  end
end
```

---

## Rule 8 — Add indexes safely

All migrations use `strong_migrations`. For large tables, add indexes concurrently and outside a transaction.

**Allowed:**

```ruby
class AddIndexToAccountsDomain < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :accounts, :domain, algorithm: :concurrently
  end
end
```

**Not allowed:**

```ruby
add_index :accounts, :domain
```

on a multi-million-row table.

---

## Rule 9 — Select only the columns you need

Wide tables like `accounts` have attachments and JSONB columns. List views should not select everything.

**Allowed:**

```ruby
Account.where(...).select(:id, :username, :display_name, :domain)
```

**Not allowed for list views:**

```ruby
Account.where(...).each { |a| puts a.username }
```

without `select`, because it loads paperclip/JSONB columns unnecessarily.

---

## Rule 10 — Profile before merging

Before opening a PR for any database change:

1. Enable Bullet and rack-mini-profiler locally.
2. Trigger the affected endpoint with realistic data.
3. Check the Rails log for repeated queries.
4. Run `EXPLAIN ANALYZE` on new complex SQL.
5. Test with the replica configuration if the change touches read/write routing.

---

## Quick decision tree

```text
Is the result rendered to a user or API consumer?
  └─ Yes → Did you paginate?
       ├─ Yes → Good.
       └─ No  → Add pagination.

Are you filtering an Active Record relation?
  └─ Yes → Is the filter in a .where() clause?
       ├─ Yes → Good.
       └─ No  → Move it to SQL.

Will you touch an association inside a loop?
  └─ Yes → Did you eager-load it?
       ├─ Yes → Good.
       └─ No  → Add includes / preload / eager_load.

Is this endpoint read-only?
  └─ Yes → Wrap it in with_read_replica.
  └─ No  → Wrap writes in with_primary.
```
