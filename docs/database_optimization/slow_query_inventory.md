# Slow Query Inventory — Patchwork Dashboard

This document lists the inefficient database access patterns currently found in the `feat-db-WR` branch. Each entry includes the file/line, the problem, the estimated impact, and a suggested fix.

Use this as a backlog. Tackle **Critical** items first, then **High**, then **Medium**.

---

## Legend

| Impact | Meaning |
| ------ | ------- |
| Critical | Unbounded result set or N+1 on hot endpoints; degrades quickly with data growth. |
| High | Inefficient but bounded, or repeated on moderately frequent endpoints. |
| Medium | Acceptable at current scale but should be cleaned up for consistency. |

---

## Critical

### 1. `KeywordFilterGroup.all` returns every row without pagination

- **File**: [app/controllers/keyword_filter_groups_controller.rb](../../app/controllers/keyword_filter_groups_controller.rb#L6)
- **Method**: `index`
- **Problem**: `KeywordFilterGroup.all` loads the entire table into memory and renders it. As the number of filter groups grows, the request becomes slower and uses more memory.
- **Suggested fix**: Add Kaminari pagination, consistent with [collections_controller.rb](../../app/controllers/collections_controller.rb#L9):

```ruby
PER_PAGE = 10

def index
  @keyword_filter_groups = KeywordFilterGroup.page(params[:page]).per(PER_PAGE)
end
```

---

### 2. `UserRole.all` loaded into memory to filter permissions in Ruby

- **File**: [app/controllers/master_admins_controller.rb](../../app/controllers/master_admins_controller.rb#L7-L9)
- **Method**: `index`
- **Problem**: `UserRole.all.select { |r| r.can?(:administrator) || r.can?(:view_newsmast_dashboard) }.map(&:id)` instantiates every role, then calls `can?` in Ruby. This is an N+1-like pattern when the role table is large and prevents the database from doing the filtering.
- **Suggested fix**: Replace with a database-level query. The exact implementation depends on how permissions are stored in `UserRole`:
- If permissions are in a JSONB/flag column:

```ruby
allowed_role_ids = UserRole.where("permissions ? 'administrator' OR permissions ? 'view_newsmast_dashboard'").pluck(:id)
```

- If permissions use bitmask columns:

```ruby
allowed_role_ids = UserRole.where(administrator: true).or(UserRole.where(view_newsmast_dashboard: true)).pluck(:id)
```

- If the role list is tiny and static, cache the IDs in Rails cache instead of querying each request.

---

### 3. `load_follow_records` filters accounts in Ruby after loading them

- **File**: [app/controllers/communities_controller.rb](../../app/controllers/communities_controller.rb#L386-L392)
- **Method**: `load_follow_records`
- **Problem**:
  - Combines two `pluck` queries in Ruby (`+`) instead of a single query.
  - Instantiates every account and then `.reject { |r| r.username == 'bsky.brid.gy' }` to filter in memory.
- **Suggested fix**:

```ruby
def load_follow_records
  account_ids = Follow.where(account_id: admin_account_id)
                      .pluck(:target_account_id)
  account_ids += FollowRequest.where(account_id: admin_account_id)
                              .pluck(:target_account_id)
  account_ids.uniq!

  @follow_records_size = Account.where(id: account_ids)
                                .where.not(username: 'bsky.brid.gy')
                                .count
  paginated_records(Account.where(id: account_ids).where.not(username: 'bsky.brid.gy'))
end
```

If both `Follow` and `FollowRequest` share the same shape, consider a `UNION` query:

```ruby
account_ids = Follow.where(account_id: admin_account_id)
                    .select(:target_account_id)
                    .union(
                      FollowRequest.where(account_id: admin_account_id).select(:target_account_id)
                    )
                    .pluck(:target_account_id)
```

---

### 4. `fetch_contributors` triggers N+1 `following_ids` queries

- **File**: [app/controllers/api/v1/communities_controller.rb](../../app/controllers/api/v1/communities_controller.rb#L281-L290)
- **Method**: `fetch_contributors`
- **Problem**: For the `:followed` branch, the code loads each `Account` and calls `account.following_ids`, which issues a query per account.
- **Suggested fix**: Eager-load the `following` association, or better, fetch the IDs in one query:

```ruby
when :followed
  Follow.where(account_id: account_ids).pluck(:target_account_id).uniq
```

This avoids loading accounts entirely when only the follower IDs are needed.

---

### 5. `boost_bot_accounts_list` queries `community_admins` once per community

- **File**: [app/controllers/api/v1/community_admins_controller.rb](../../app/controllers/api/v1/community_admins_controller.rb#L57-L67)
- **Method**: `boost_bot_accounts_list`
- **Problem**: `community.community_admins.first` runs a query for every community in the loop.
- **Suggested fix**: Eager-load `community_admins` and, if needed, `account`:

```ruby
communities = Community.where(channel_type: ['channel_feed', 'channel'])
                       .where(deleted_at: nil)
                       .includes(community_admins: :account)

communities.each do |community|
  community_admin = community.community_admins.first
  next unless community_admin
  ...
end
```

If `community_admins` is large, consider a `has_one` association for the boost bot role, or filter at the database level.

---

## High

### 6. `prepare_filter_group_data` iterates `keyword_filters` without eager loading

- **File**: [app/controllers/keyword_filter_groups_controller.rb](../../app/controllers/keyword_filter_groups_controller.rb#L120)
- **Method**: `prepare_filter_group_data`
- **Problem**: `@keyword_filter_group.keyword_filters.map { ... }` may trigger N+1 if the association is not already loaded.
- **Suggested fix**: Ensure the group is loaded with its filters before serialization:

```ruby
def prepare_filter_group_data
  @keyword_filter_group = KeywordFilterGroup.includes(:keyword_filters).find(@keyword_filter_group.id)
  ...
end
```

Or use `@keyword_filter_group.keyword_filters.load` before the map.

---

### 7. `load_follower_records` and `load_muted_accounts` could combine count and list queries

- **File**: [app/controllers/communities_controller.rb](../../app/controllers/communities_controller.rb#L394-L408)
- **Methods**: `load_follower_records`, `load_muted_accounts`
- **Problem**: `load_muted_accounts` plucks IDs, gets `.size` on the array, then loads the same IDs again for pagination. `load_follower_records` does not filter the bridge bot.
- **Suggested fix** for `load_muted_accounts`:

```ruby
def load_muted_accounts
  scope = Account.joins(:mutes_as_target).where(mutes: { account_id: admin_account_id })
  @muted_accounts_size = scope.count
  paginated_records(scope)
end
```

For `load_follower_records`, apply the same `where.not(username: 'bsky.brid.gy')` filter if the product requirement allows it.

---

### 8. `download_csv_by_server_setting` builds CSV without streaming

- **File**: [app/controllers/keyword_filter_groups_controller.rb](../../app/controllers/keyword_filter_groups_controller.rb#L100-L118)
- **Method**: `download_csv_by_server_setting`
- **Problem**: Although `find_each` is used, the entire CSV string is built in memory before `send_data`. For very large filter sets this can consume significant memory.
- **Suggested fix**: Use `CSV` streaming with `response.stream` or `Enumerator` so rows are written to the client as they are generated:

```ruby
def download_csv_by_server_setting
  server_setting_id = params[:server_setting_id]
  server_setting = ServerSetting.find_by_id(server_setting_id)

  set_streaming_headers(filename: "#{server_setting&.name&.parameterize}.csv")

  response.stream.write CSV.generate_line(["Group Name", "Server Setting", "Group Active", "Keyword", "Filter Type", "Custom Group"])

  KeywordFilter.joins(:keyword_filter_group)
               .where(keyword_filter_groups: { server_setting_id: server_setting_id })
               .find_each do |kf|
    group = kf.keyword_filter_group
    response.stream.write CSV.generate_line([
      group&.name,
      group&.server_setting&.name,
      group&.is_active ? 'True' : 'False',
      kf.keyword,
      kf.filter_type,
      group&.is_custom ? 'True' : 'False'
    ])
  end
ensure
  response.stream.close
end
```

Add a helper for streaming headers if one does not already exist.

---

## Medium

### 9. `download_csv` serializes one group without eager loading

- **File**: [app/controllers/keyword_filter_groups_controller.rb](../../app/controllers/keyword_filter_groups_controller.rb#L80-L95)
- **Method**: `download_csv`
- **Problem**: `filters = @keyword_filter_group.keyword_filters` is small for a single group, but it could still benefit from being loaded eagerly in `set_keyword_filter_group`.
- **Suggested fix**: Update `set_keyword_filter_group`:

```ruby
def set_keyword_filter_group
  @keyword_filter_group = KeywordFilterGroup.includes(:keyword_filters, :server_setting).find(params[:id])
end
```

---

### 10. Nested subquery in `AccountsController`

- **File**: [app/controllers/accounts_controller.rb](../../app/controllers/accounts_controller.rb#L51)
- **Problem**: A nested subquery in `pluck` is acceptable but can often be flattened to a join or an `EXISTS` clause for better performance.
- **Suggested fix**: Review the generated SQL with `EXPLAIN ANALYZE` and rewrite as a `JOIN` or `EXISTS` if the planner shows poor performance.

---

## Recommended fix order

1. Fix unbounded pagination in `KeywordFilterGroupsController#index`.
2. Replace Ruby permission filtering in `MasterAdminsController#index`.
3. Fix the `fetch_contributors` N+1 in `Api::V1::CommunitiesController`.
4. Fix the `boost_bot_accounts_list` N+1 in `Api::V1::CommunityAdminsController`.
5. Clean up `load_follow_records` / `load_follower_records` / `load_muted_accounts`.
6. Add eager loading to `prepare_filter_group_data` and `download_csv`.
7. Convert large CSV exports to streaming responses.
8. Review and optimize the nested subquery in `AccountsController`.
