class AddKeyToServerSettings < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    unless column_exists?(:server_settings, :key)
      add_column :server_settings, :key, :string
    end

    unless index_exists?(:server_settings, :key)
      add_index :server_settings, :key, unique: true, where: "key IS NOT NULL", name: "index_server_settings_on_key", algorithm: :concurrently
    end
  end
end
