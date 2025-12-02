class AddDidValueAndBlueskyBridgeEnabledToUsers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_column :users, :did_value, :string, default: nil, null: true unless column_exists?(:users, :did_value)
    add_column :users, :bluesky_bridge_enabled, :boolean, default: false, null: false unless column_exists?(:users, :bluesky_bridge_enabled)
  end
end
