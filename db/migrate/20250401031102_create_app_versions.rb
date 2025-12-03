class CreateAppVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_app_versions, if_not_exists: true do |t|
      t.string :version_name
      t.timestamps
    end

    unless index_exists?(:patchwork_app_versions, :version_name)
      add_index :patchwork_app_versions, :version_name, unique: true
    end
  end
end