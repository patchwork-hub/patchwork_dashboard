class CreatePatchworkAutoFollowAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_auto_follow_accounts, if_not_exists: true do |table|
      table.references :patchwork_auto_follow, null: false, foreign_key: { on_delete: :cascade }, index: false
      table.references :account, null: false, foreign_key: { on_delete: :cascade }
      table.integer :position, null: false, default: 0
      table.timestamps
    end
    add_index :patchwork_auto_follow_accounts, [:patchwork_auto_follow_id, :account_id], unique: true, name: 'index_auto_follow_accounts_unique', if_not_exists: true
  end
end