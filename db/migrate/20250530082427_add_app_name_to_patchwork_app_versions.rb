class AddAppNameToPatchworkAppVersions < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_app_versions, :app_name)
      add_column :patchwork_app_versions, :app_name, :integer, default: 0, null: false
    end
  end
end
