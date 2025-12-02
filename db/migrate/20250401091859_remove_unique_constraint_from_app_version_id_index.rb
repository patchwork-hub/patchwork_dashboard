class RemoveUniqueConstraintFromAppVersionIdIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    if index_exists?(:patchwork_app_version_histories, :app_version_id, unique: true)
      remove_index :patchwork_app_version_histories, :app_version_id
    end

    unless index_exists?(:patchwork_app_version_histories, :app_version_id)
      add_index :patchwork_app_version_histories, :app_version_id, algorithm: :concurrently
    end
  end
end
