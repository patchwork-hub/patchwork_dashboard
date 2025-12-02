class UpdateVersionNameIndexOnAppVersions < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!
  def change
    if index_exists?(:patchwork_app_versions, :version_name, unique: true)
      remove_index :patchwork_app_versions, :version_name
    end

    unless index_exists?(:patchwork_app_versions, [:version_name, :app_name], name: 'index_patchwork_app_versions_on_version_name_and_app_name')
      add_index :patchwork_app_versions, [:version_name, :app_name], unique: true, algorithm: :concurrently
    end
  end
end
