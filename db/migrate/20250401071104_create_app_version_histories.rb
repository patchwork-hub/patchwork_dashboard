class CreateAppVersionHistories < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_app_version_histories, if_not_exists: true do |t|
      t.references :app_version, null: false, foreign_key: {to_table: :patchwork_app_versions}
      t.string :os_type
      t.boolean :deprecated, default: false
      t.timestamps
    end

    if index_exists?(:patchwork_app_version_histories, :app_version_id)
      remove_index :patchwork_app_version_histories, :app_version_id
    end

    unless index_exists?(:patchwork_app_version_histories, :app_version_id, unique: true)
      add_index :patchwork_app_version_histories, :app_version_id, unique: true
    end
  end
end
