class AddAttributesWaitLists < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def self.up
    unless column_exists?(:patchwork_wait_lists, :account_id)
      add_reference :patchwork_wait_lists, :account, null: true, index: { algorithm: :concurrently }
    end
    
    unless column_exists?(:patchwork_wait_lists, :confirmed_at)
      add_column :patchwork_wait_lists, :confirmed_at, :datetime
    end
  end

  def self.down
    if column_exists?(:patchwork_wait_lists, :account_id)
      remove_foreign_key :patchwork_wait_lists, :accounts if foreign_key_exists?(:patchwork_wait_lists, :accounts)
      remove_index :patchwork_wait_lists, :account_id, algorithm: :concurrently if index_exists?(:patchwork_wait_lists, :account_id)
      remove_column :patchwork_wait_lists, :account_id
    end
    
    if column_exists?(:patchwork_wait_lists, :confirmed_at)
      remove_column :patchwork_wait_lists, :confirmed_at
    end
  end
end