class AddStatusToCommunityAdmins < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def self.up
    unless column_exists?(:patchwork_communities_admins, :account_status)
      add_column :patchwork_communities_admins, :account_status, :integer, null: false, default: 0
    end
  end

  def self.down
    if column_exists?(:patchwork_communities_admins, :account_status)
      safety_assured { remove_column :patchwork_communities_admins, :account_status }
    end
  end
end