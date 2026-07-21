require "test_helper"

class DatabaseHelperTest < ActiveSupport::TestCase
  include DatabaseHelper

  setup do
    @original_replica_db_name = ENV['REPLICA_DB_NAME']
    @original_replica_database_url = ENV['REPLICA_DATABASE_URL']
  end

  teardown do
    ENV['REPLICA_DB_NAME'] = @original_replica_db_name
    ENV['REPLICA_DATABASE_URL'] = @original_replica_database_url
  end

  test "replica_enabled? is false when replica env vars are unset" do
    ENV.delete('REPLICA_DB_NAME')
    ENV.delete('REPLICA_DATABASE_URL')

    assert_not replica_enabled?
  end

  test "replica_enabled? is true when REPLICA_DB_NAME is set" do
    ENV['REPLICA_DB_NAME'] = 'dashboard_production'
    ENV.delete('REPLICA_DATABASE_URL')

    assert replica_enabled?
  end

  test "replica_enabled? is true when REPLICA_DATABASE_URL is set" do
    ENV.delete('REPLICA_DB_NAME')
    ENV['REPLICA_DATABASE_URL'] = 'postgres://readonly@localhost/dashboard_production'

    assert replica_enabled?
  end
end
