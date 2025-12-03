class CreateUseageWaitLists < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_useage_wait_lists, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: {to_table: :accounts}
      t.references :wait_list, null: false, foreign_key: {to_table: :patchwork_wait_lists}
      t.timestamps
    end
    
    unless index_exists?(:patchwork_useage_wait_lists, [:account_id, :wait_list_id])
      add_index :patchwork_useage_wait_lists, [:account_id, :wait_list_id], unique: true
    end
  end
end
