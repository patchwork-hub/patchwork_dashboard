class AddTypeWaitLists < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def self.up
    unless column_exists?(:patchwork_wait_lists, :channel_type)
      add_column :patchwork_wait_lists, :channel_type, :integer, null: false, default: 0
    end
  end

  def self.down
    if column_exists?(:patchwork_wait_lists, :channel_type)
      safety_assured { remove_column :patchwork_wait_lists, :channel_type }
    end
  end
end