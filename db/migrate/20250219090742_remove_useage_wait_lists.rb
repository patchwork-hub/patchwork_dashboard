class RemoveUseageWaitLists < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    drop_table :patchwork_useage_wait_lists, if_exists: true
  end
end