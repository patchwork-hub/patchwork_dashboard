# Read/Write Database Guideline

This guide explains how to safely use primary (write) and replica (read) database routing in Patchwork Dashboard.

## Goal

- Keep all writes on primary by default.
- Move safe, read-heavy paths to replica.
- Avoid consistency bugs (stale read after write).
- Make rollback simple by toggling environment variables.

## Current Integration

The project already includes role routing helpers:

- `ApplicationRecord` maps roles to databases:
  - `writing` -> `primary`
  - `reading` -> `replica`
- `DatabaseHelper` provides:
  - `with_read_replica { ... }`
  - `with_primary { ... }`

If replica is not enabled, helper blocks fall back to normal behavior (primary-only mode).

## Replica Enablement

Replica routing is enabled when either of these is set:

- `REPLICA_DB_NAME`
- `REPLICA_DATABASE_URL`

For local development, passwordless replica is supported by default:

```env
REPLICA_DB_HOST=localhost
REPLICA_DB_USER=postgres_readonly
REPLICA_DB_NAME=channel_staging
REPLICA_DB_PASS=
REPLICA_DB_PORT=5432
```

Set `REPLICA_DB_PASS` only if your readonly role requires password auth.

## Quick Rules

1. Use `with_read_replica` for read-only, high-volume queries.
2. Use `with_primary` for writes and critical consistency paths.
3. Do not perform writes inside `with_read_replica`.
4. Avoid replica for immediate read-after-write flows.
5. Keep auth/session/security-sensitive reads on primary.

## When To Use Replica

Good candidates:

- Listing pages
- Search endpoints
- Dashboard counters and reports
- Read-only moderation queues with acceptable staleness

Do not move:

- Login/session checks
- "Write then immediately read" workflows
- Any path requiring strict latest-state guarantees

## Controller Examples

### Read-heavy endpoint

```ruby
def index
  with_read_replica do
    @channels = Channel.active.order(updated_at: :desc).limit(100)
  end
end
```

### Write endpoint

```ruby
def update
  with_primary do
    channel = Channel.find(params[:id])
    channel.update!(channel_params)
  end
end
```

## Service Example

```ruby
class RefreshCollectionService
  include DatabaseHelper

  def call(collection_id)
    collection = with_read_replica { Collection.find(collection_id) }

    with_primary do
      collection.touch(:refreshed_at)
    end
  end
end
```

## Job Example

```ruby
class RebuildStatsJob < ApplicationJob
  include DatabaseHelper

  def perform
    ids = with_read_replica { Community.active.limit(1000).pluck(:id) }

    with_primary do
      ids.each { |id| StatsSnapshot.refresh_for!(id) }
    end
  end
end
```

## Consistency Guidance

If a request writes data and then must read the latest value in the same flow, keep the read on primary.

Example:

```ruby
with_primary do
  post.update!(published: true)
  latest_state = Post.find(post.id)
  # latest_state is guaranteed fresh here
end
```

## Testing Guidance

Add tests for:

1. Replica toggle behavior (`REPLICA_DB_NAME` / `REPLICA_DATABASE_URL`).
2. Endpoints wrapped in `with_read_replica`.
3. Write paths wrapped in `with_primary`.
4. Write prevention inside `with_read_replica`.
5. Fresh test DB initialization when schema defaults rely on PostgreSQL helper functions.

When a clean test database is created from schema load, PostgreSQL must already have the custom `timestamp_id(text)` helper function that several table defaults use. If you run into `PG::UndefinedFunction: timestamp_id(text)`, recreate the test database from schema after the migration that defines the function:

```bash
RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load
```

Example safety test:

```ruby
test "write inside read replica block is prevented" do
  assert_raises(ActiveRecord::ReadOnlyError) do
    with_read_replica do
      Community.create!(name: "not_allowed")
    end
  end
end
```

## Rollout Strategy

1. Deploy helper + config changes first (no behavior migration).
2. Migrate one low-risk read path at a time.
3. Monitor latency, SQL errors, and stale-read complaints.
4. Expand coverage incrementally.

## Incident Rollback

If replica causes issues:

1. Unset `REPLICA_DB_NAME` and `REPLICA_DATABASE_URL`.
2. Restart web and worker processes.
3. Confirm app is running primary-only.
4. Re-enable after replica issue is resolved.

## Common Pitfalls

- Wrapping mixed read/write logic in `with_read_replica`.
- Accidentally relying on replica for fresh state.
- Enabling replica in env without verifying readonly user grants.
- Assuming blank replica password works when pg_hba requires password auth.

## Implementation Checklist

- [ ] Replica connection variables set correctly.
- [ ] Readonly role has connect/select permissions.
- [ ] Low-risk read endpoint migrated first.
- [ ] Write paths explicitly wrapped where needed.
- [ ] Tests added or updated.
- [ ] Rollback toggle verified in staging.
