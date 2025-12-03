class AddAccountToPatchworkCommunitiesAdmins < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    unless column_exists?(:patchwork_communities_admins, :account_id)
      add_reference :patchwork_communities_admins, :account, null: true, index: { algorithm: :concurrently }
    end
    
    unless foreign_key_exists?(:patchwork_communities_admins, :accounts)
      add_foreign_key :patchwork_communities_admins, :accounts, on_delete: :cascade, validate: false
    end
  end
end