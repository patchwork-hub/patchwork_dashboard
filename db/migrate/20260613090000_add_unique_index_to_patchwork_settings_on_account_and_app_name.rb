class AddUniqueIndexToPatchworkSettingsOnAccountAndAppName < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  INDEX_NAME = 'index_patchwork_settings_on_account_id_and_app_name'

  def up
    add_index :patchwork_settings,
      [:account_id, :app_name],
      unique: true,
      name: INDEX_NAME,
      algorithm: :concurrently,
      if_not_exists: true
  end

  def down
    remove_index :patchwork_settings,
      name: INDEX_NAME,
      algorithm: :concurrently,
      if_exists: true
  end
end
